#!/usr/bin/env bash
set -u

emit() {
    jq -cn --arg id "$1" --arg label "$2" --argjson used "$3" \
        --argjson todayCost "${4:-0}" --argjson monthCost "${5:-0}" \
        --argjson todayTokens "${6:-0}" --argjson monthTokens "${7:-0}" \
        '{id:$id,label:$label,used:($used|round),remaining:(100-($used|round)),todayCost:$todayCost,monthCost:$monthCost,todayTokens:$todayTokens,monthTokens:$monthTokens}'
}

if [[ ${1:-} == --self-test ]]; then
    emit codex Session 41.4 1.25 7.5 1000 5000 |
        jq -e '.id == "codex" and .used == 41 and .remaining == 59 and .monthCost == 7.5 and .monthTokens == 5000' >/dev/null
    exit
fi

enabled=,${1:-},
cache_seconds=${2:-300}
[[ $cache_seconds =~ ^[0-9]+$ ]] || cache_seconds=300
force=${3:-}
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/serashell/ai-usage
cache_key=$(printf '%s' "$1" | tr -cd 'a-zA-Z0-9,_-')
usage_cache=$cache_dir/usage-v5-$cache_key.jsonl
pricing_cache=$cache_dir/pricing-litellm.json
supplement_cache=$cache_dir/pricing-openusage.json
mkdir -p "$cache_dir"

fresh() {
    [[ -r "$1" ]] && (( $(date +%s) - $(stat -c %Y "$1") < $2 ))
}

if [[ $force != --force ]] && fresh "$usage_cache" "$cache_seconds"; then
    cat "$usage_cache"
    exit
fi

if ! fresh "$supplement_cache" 3600; then
    supplement_tmp=$(mktemp "$cache_dir/supplement.XXXXXX")
    if curl --silent --show-error --fail --max-time 20 \
        https://robinebers.github.io/openusage/pricing_supplement.json \
        -o "$supplement_tmp" && jq -e '.pricing | type == "object"' "$supplement_tmp" >/dev/null; then
        mv "$supplement_tmp" "$supplement_cache"
    else
        rm -f "$supplement_tmp"
    fi
fi

if ! fresh "$pricing_cache" 3600; then
    pricing_tmp=$(mktemp "$cache_dir/pricing.XXXXXX")
    if curl --silent --show-error --fail --max-time 20 \
        https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json \
        -o "$pricing_tmp" && jq -e 'type == "object"' "$pricing_tmp" >/dev/null; then
        mv "$pricing_tmp" "$pricing_cache"
    else
        rm -f "$pricing_tmp"
    fi
fi

enabled_provider() {
    [[ "$enabled" == *,$1,* ]]
}

request() {
    local token=$1 url=$2 method=$3 config response
    local -a curl_args
    shift 3
    config=$(mktemp)
    chmod 600 "$config"
    {
        printf 'header = "Authorization: Bearer %s"\n' "$token"
        for header in "$@"; do
            printf 'header = "%s"\n' "$header"
        done
    } > "$config"
    curl_args=(--silent --show-error --fail --max-time 10 --config "$config" --request "$method")
    [[ $method == POST ]] && curl_args+=(--data '{}')
    response=$(curl "${curl_args[@]}" "$url" 2>/dev/null) || true
    rm -f "$config"
    printf '%s' "$response"
}

claude_spend() {
    [[ -r "$pricing_cache" ]] || { printf '0 0 0 0'; return; }
    local today_start
    today_start=$(date -d 'today 00:00' +%s)
    find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects" -type f -name '*.jsonl' -mtime -31 -print0 2>/dev/null |
        while IFS= read -r -d '' file; do
            jq -r --argjson todayStart "$today_start" --slurpfile prices "$pricing_cache" '
                select(.message.usage and .timestamp)
                | .message.usage as $u
                | (.message.model // "") as $model
                | ($prices[0][$model] // $prices[0]["anthropic/" + $model] // {}) as $rate
                | (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0) + ($u.output_tokens // 0)) as $tokens
                | (.costUSD // (
                    ($u.input_tokens // 0) * ($rate.input_cost_per_token // 0)
                    + ($u.cache_creation_input_tokens // 0) * ($rate.cache_creation_input_token_cost // $rate.input_cost_per_token // 0)
                    + ($u.cache_read_input_tokens // 0) * ($rate.cache_read_input_token_cost // 0)
                    + ($u.output_tokens // 0) * ($rate.output_cost_per_token // 0)
                  )) as $cost
                | ((.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) >= $todayStart) as $isToday
                | [if $isToday then $cost else 0 end, $cost, if $isToday then $tokens else 0 end, $tokens]
                | @tsv' "$file" 2>/dev/null
        done | awk '{tc += $1; mc += $2; tt += $3; mt += $4} END {printf "%.6f %.6f %.0f %.0f", tc, mc, tt, mt}'
}

codex_spend() {
    [[ -r "$pricing_cache" ]] || { printf '0 0 0 0'; return; }
    local codex_root today_start
    codex_root=${CODEX_HOME:-$HOME/.codex}
    today_start=$(date -d 'today 00:00' +%s)
    find "$codex_root/sessions" "$codex_root/archived_sessions" -type f -name '*.jsonl' -mtime -31 -print0 2>/dev/null |
        while IFS= read -r -d '' file; do
            jq -sr --argjson todayStart "$today_start" --slurpfile prices "$pricing_cache" '
                ([.[] | select(.type == "turn_context") | .payload.model // .payload.model_name] | map(select(. != null)) | last // "gpt-5") as $model
                | ($prices[0][$model] // $prices[0]["openai/" + $model] // {}) as $rate
                | [.[] | select(.type == "event_msg" and .payload.type == "token_count" and .payload.info.last_token_usage)
                    | .payload.info.last_token_usage as $u
                    | ((($u.input_tokens // 0) - ($u.cached_input_tokens // 0)) * ($rate.input_cost_per_token // 0)
                      + ($u.cached_input_tokens // 0) * ($rate.cache_read_input_token_cost // $rate.input_cost_per_token // 0)
                      + ($u.output_tokens // 0) * ($rate.output_cost_per_token // 0)) as $cost
                    | (($u.input_tokens // 0) + ($u.output_tokens // 0)) as $tokens
                    | ((.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) >= $todayStart) as $isToday
                    | [if $isToday then $cost else 0 end, $cost, if $isToday then $tokens else 0 end, $tokens]]
                | reduce .[] as $row ([0,0,0,0]; [.[0]+$row[0], .[1]+$row[1], .[2]+$row[2], .[3]+$row[3]])
                | @tsv' "$file" 2>/dev/null
        done | awk '{tc += $1; mc += $2; tt += $3; mt += $4} END {printf "%.6f %.6f %.0f %.0f", tc, mc, tt, mt}'
}

cursor_spend() {
    local token=$1 segment subject user start end config csv_file today
    [[ -r "$pricing_cache" && -r "$supplement_cache" ]] || { printf '0 0 0 0'; return; }
    segment=$(printf '%s' "$token" | cut -d. -f2 | tr '_-' '/+')
    while (( ${#segment} % 4 )); do segment="${segment}="; done
    subject=$(printf '%s' "$segment" | base64 -d 2>/dev/null | jq -r '.sub // empty')
    user=${subject#*|}
    [[ -n "$user" ]] || { printf '0 0 0 0'; return; }
    start=$(( $(date -d '29 days ago 00:00' +%s) * 1000 ))
    end=$(( $(date +%s) * 1000 ))
    today=$(date +%F)
    config=$(mktemp)
    csv_file=$(mktemp "$cache_dir/cursor.XXXXXX")
    chmod 600 "$config" "$csv_file"
    printf 'header = "Cookie: WorkosCursorSessionToken=%s%%3A%%3A%s"\nheader = "Accept: text/csv"\n' "$user" "$token" > "$config"
    if ! curl --silent --show-error --fail --max-time 30 --config "$config" --get \
        --data-urlencode "startDate=$start" --data-urlencode "endDate=$end" --data-urlencode 'strategy=tokens' \
        https://cursor.com/api/dashboard/export-usage-events-csv -o "$csv_file" 2>/dev/null; then
        rm -f "$config" "$csv_file"
        printf '0 0 0 0'
        return
    fi
    python - "$csv_file" "$pricing_cache" "$supplement_cache" "$today" <<'PY'
import csv, datetime, json, re, sys

csv_path, prices_path, supplement_path, today = sys.argv[1:]
with open(prices_path) as file:
    prices = json.load(file)
with open(supplement_path) as file:
    supplement = json.load(file)

def rate_for(model):
    canonical = model
    for rule in supplement.get("alias_rules", []):
        try:
            if re.search(rule["pattern"], model):
                canonical = rule["canonical"]
                break
        except re.error:
            continue
    rate = supplement.get("pricing", {}).get(canonical)
    if rate:
        return tuple(float(rate.get(key, 0)) / 1_000_000 for key in (
            "input_per_million", "cache_write_per_million", "cache_read_per_million", "output_per_million"
        ))
    for key in (canonical, model, "anthropic/" + canonical, "openai/" + canonical, "xai/" + canonical):
        rate = prices.get(key)
        if rate:
            input_rate = float(rate.get("input_cost_per_token", 0))
            return (
                input_rate,
                float(rate.get("cache_creation_input_token_cost", input_rate)),
                float(rate.get("cache_read_input_token_cost", input_rate)),
                float(rate.get("output_cost_per_token", 0)),
            )
    return None

totals = [0.0, 0.0, 0, 0]
def local_day(raw):
    try:
        parsed = datetime.datetime.fromisoformat(raw.replace("Z", "+00:00"))
        return (parsed.astimezone() if parsed.tzinfo else parsed).date().isoformat()
    except ValueError:
        return raw[:10]

with open(csv_path, newline="") as file:
    rows = list(csv.DictReader(file))
available_days = [local_day(row.get("Date") or "") for row in rows if row.get("Date")]
display_day = today if today in available_days else max(available_days, default=today)
for row in rows:
        try:
            values = [int((row.get(key) or "0").replace(",", "")) for key in (
                "Input (w/o Cache Write)", "Input (w/ Cache Write)", "Cache Read", "Output Tokens"
            )]
        except ValueError:
            continue
        rate = rate_for((row.get("Model") or "").strip())
        if not rate:
            continue
        cost = sum(tokens * price for tokens, price in zip(values, rate))
        tokens = sum(values)
        totals[1] += cost
        totals[3] += tokens
        if local_day(row.get("Date") or "") == display_day:
            totals[0] += cost
            totals[2] += tokens
print(f"{totals[0]:.6f} {totals[1]:.6f} {totals[2]} {totals[3]}", end="")
PY
    rm -f "$config" "$csv_file"
}

claude() {
    local file token body session weekly today_cost month_cost today_tokens month_tokens
    file=$HOME/.claude/.credentials.json
    [[ -r "$file" ]] || return
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$file")
    [[ -n "$token" ]] || return
    body=$(request "$token" https://api.anthropic.com/api/oauth/usage GET 'Accept: application/json' 'anthropic-beta: oauth-2025-04-20' 'User-Agent: claude-code/2.1.69')
    session=$(jq -r '.five_hour.utilization // empty' <<< "$body")
    weekly=$(jq -r '.seven_day.utilization // empty' <<< "$body")
    read -r today_cost month_cost today_tokens month_tokens <<< "$(claude_spend)"
    [[ "$session" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit claude Session "$session" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens"
    [[ "$weekly" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit claude Weekly "$weekly" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens"
}

codex() {
    local file token account body session weekly today_cost month_cost today_tokens month_tokens
    file=$HOME/.codex/auth.json
    [[ -r "$file" ]] || file=$HOME/.config/codex/auth.json
    [[ -r "$file" ]] || return
    token=$(jq -r '.tokens.access_token // empty' "$file")
    account=$(jq -r '.tokens.account_id // empty' "$file")
    [[ -n "$token" ]] || return
    body=$(request "$token" https://chatgpt.com/backend-api/wham/usage GET 'Accept: application/json' "ChatGPT-Account-Id: $account")
    session=$(jq -r '.rate_limit.primary_window.used_percent // empty' <<< "$body")
    weekly=$(jq -r '.rate_limit.secondary_window.used_percent // empty' <<< "$body")
    read -r today_cost month_cost today_tokens month_tokens <<< "$(codex_spend)"
    [[ "$session" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit codex Session "$session" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens"
    [[ "$weekly" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit codex Weekly "$weekly" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens"
}

cursor() {
    command -v sqlite3 >/dev/null || return
    command -v python >/dev/null || return
    local file token body total auto api today_cost month_cost today_tokens month_tokens
    for file in "${XDG_CONFIG_HOME:-$HOME/.config}/Cursor/User/globalStorage/state.vscdb" "${XDG_CONFIG_HOME:-$HOME/.config}/cursor/User/globalStorage/state.vscdb"; do
        [[ -r "$file" ]] && break
    done
    [[ -r "$file" ]] || return
    token=$(sqlite3 -readonly "$file" "SELECT value FROM ItemTable WHERE key='cursorAuth/accessToken' LIMIT 1;" 2>/dev/null)
    [[ -n "$token" ]] || return
    body=$(request "$token" https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage POST 'Content-Type: application/json' 'Connect-Protocol-Version: 1')
    total=$(jq -r '.planUsage.totalPercentUsed // empty' <<< "$body")
    auto=$(jq -r '.planUsage.autoPercentUsed // empty' <<< "$body")
    api=$(jq -r '.planUsage.apiPercentUsed // empty' <<< "$body")
    read -r today_cost month_cost today_tokens month_tokens <<< "$(cursor_spend "$token")"
    [[ "$total" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit cursor Total "$total" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens"
    [[ "$auto" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit cursor Auto "$auto" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens"
    [[ "$api" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit cursor API "$api" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens"
}

opencode() {
    local file token body rolling weekly monthly
    file=$HOME/.local/share/opencode/auth.json
    [[ -r "$file" ]] || return
    token=$(jq -r '."opencode-go".key // empty' "$file")
    [[ -n "$token" ]] || return
    body=$(request "$token" https://opencode.ai/zen/go/v1/usage GET 'Accept: application/json')
    rolling=$(jq -r '.usage.rolling.percent // empty' <<< "$body")
    weekly=$(jq -r '.usage.weekly.percent // empty' <<< "$body")
    monthly=$(jq -r '.usage.monthly.percent // empty' <<< "$body")
    [[ "$rolling" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit opencode Session "$rolling"
    [[ "$weekly" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit opencode Weekly "$weekly"
    [[ "$monthly" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit opencode Monthly "$monthly"
}

usage_tmp=$(mktemp "$cache_dir/usage.XXXXXX")
{
    enabled_provider claude && claude
    enabled_provider codex && codex
    enabled_provider cursor && cursor
    enabled_provider opencode && opencode
} > "$usage_tmp"

if [[ -s "$usage_tmp" ]]; then
    mv "$usage_tmp" "$usage_cache"
else
    rm -f "$usage_tmp"
fi

[[ -r "$usage_cache" ]] && cat "$usage_cache"
