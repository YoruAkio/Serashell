#!/usr/bin/env bash
set -u

emit() {
    jq -cn --arg id "$1" --arg label "$2" --argjson used "$3" \
        --argjson todayCost "${4:-0}" --argjson monthCost "${5:-0}" \
        --argjson todayTokens "${6:-0}" --argjson monthTokens "${7:-0}" \
        --argjson yesterdayCost "${8:-0}" --argjson yesterdayTokens "${9:-0}" \
        --arg plan "${10:-}" \
        --argjson accountOnly "${11:-false}" \
        --argjson resetsAt "${12:-0}" \
        '{id:$id,label:$label,used:($used|round),remaining:(100-($used|round)),todayCost:$todayCost,monthCost:$monthCost,todayTokens:$todayTokens,monthTokens:$monthTokens,yesterdayCost:$yesterdayCost,yesterdayTokens:$yesterdayTokens,plan:$plan,accountOnly:$accountOnly,resetsAt:$resetsAt}'
}

# @note iso8601 (or anything date -d parses) to epoch seconds, 0 when missing/unparseable
to_epoch() {
    local epoch
    [[ -n "${1:-}" ]] || { printf '0'; return; }
    epoch=$(date -d "$1" +%s 2>/dev/null) || epoch=0
    printf '%s' "$epoch"
}

format_plan() {
    case "${1,,}" in
        free|*free*|*starter*) printf 'Free' ;;
        plus|chatgpt_plus) printf 'Plus' ;;
        ultra|*ultra*) printf 'Ultra' ;;
        pro|chatgpt_pro|*pro*) printf 'Pro' ;;
        max|chatgpt_max) printf 'Max' ;;
        team) printf 'Team' ;;
        enterprise) printf 'Enterprise' ;;
        *) printf '%s' "$1" ;;
    esac
}

if [[ ${1:-} == --self-test ]]; then
    emit codex Session 41.4 1.25 7.5 1000 5000 0.75 600 Pro false 1760000000 |
        jq -e '.id == "codex" and .used == 41 and .remaining == 59 and .plan == "Pro" and .monthCost == 7.5 and .monthTokens == 5000 and .yesterdayCost == 0.75 and .yesterdayTokens == 600 and .resetsAt == 1760000000' >/dev/null
    exit
fi

enabled=,${1:-},
cache_seconds=${2:-300}
[[ $cache_seconds =~ ^[0-9]+$ ]] || cache_seconds=300
force=${3:-}
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/serashell/ai-usage
cache_key=$(printf '%s' "$1" | tr -cd 'a-zA-Z0-9,_-')
usage_cache=$cache_dir/usage-v11-$cache_key.jsonl
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
    [[ -r "$pricing_cache" ]] || { printf '0 0 0 0 0 0'; return; }
    local today_start yesterday_start
    today_start=$(date -d 'today 00:00' +%s)
    yesterday_start=$(date -d 'yesterday 00:00' +%s)
    find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects" -type f -name '*.jsonl' -mtime -31 -print0 2>/dev/null |
        while IFS= read -r -d '' file; do
            jq -r --argjson todayStart "$today_start" --argjson yesterdayStart "$yesterday_start" --slurpfile prices "$pricing_cache" '
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
                | ((.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) >= $yesterdayStart and (.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) < $todayStart) as $isYesterday
                | [if $isToday then $cost else 0 end, $cost, if $isToday then $tokens else 0 end, $tokens, if $isYesterday then $cost else 0 end, if $isYesterday then $tokens else 0 end]
                | @tsv' "$file" 2>/dev/null
        done | awk '{tc += $1; mc += $2; tt += $3; mt += $4; yc += $5; yt += $6} END {printf "%.6f %.6f %.0f %.0f %.6f %.0f", tc, mc, tt, mt, yc, yt}'
}

codex_spend() {
    [[ -r "$pricing_cache" ]] || { printf '0 0 0 0 0 0'; return; }
    local codex_root today_start yesterday_start
    codex_root=${CODEX_HOME:-$HOME/.codex}
    today_start=$(date -d 'today 00:00' +%s)
    yesterday_start=$(date -d 'yesterday 00:00' +%s)
    find "$codex_root/sessions" "$codex_root/archived_sessions" -type f -name '*.jsonl' -mtime -31 -print0 2>/dev/null |
        while IFS= read -r -d '' file; do
            jq -sr --argjson todayStart "$today_start" --argjson yesterdayStart "$yesterday_start" --slurpfile prices "$pricing_cache" '
                ([.[] | select(.type == "turn_context") | .payload.model // .payload.model_name] | map(select(. != null)) | last // "gpt-5") as $model
                | ($prices[0][$model] // $prices[0]["openai/" + $model] // {}) as $rate
                | [.[] | select(.type == "event_msg" and .payload.type == "token_count" and .payload.info.last_token_usage)
                    | .payload.info.last_token_usage as $u
                    | ((($u.input_tokens // 0) - ($u.cached_input_tokens // 0)) * ($rate.input_cost_per_token // 0)
                      + ($u.cached_input_tokens // 0) * ($rate.cache_read_input_token_cost // $rate.input_cost_per_token // 0)
                      + ($u.output_tokens // 0) * ($rate.output_cost_per_token // 0)) as $cost
                    | (($u.input_tokens // 0) + ($u.output_tokens // 0)) as $tokens
                    | ((.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) >= $todayStart) as $isToday
                    | ((.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) >= $yesterdayStart and (.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) < $todayStart) as $isYesterday
                    | [if $isToday then $cost else 0 end, $cost, if $isToday then $tokens else 0 end, $tokens, if $isYesterday then $cost else 0 end, if $isYesterday then $tokens else 0 end]]
                | reduce .[] as $row ([0,0,0,0,0,0]; [.[0]+$row[0], .[1]+$row[1], .[2]+$row[2], .[3]+$row[3], .[4]+$row[4], .[5]+$row[5]])
                | @tsv' "$file" 2>/dev/null
        done | awk '{tc += $1; mc += $2; tt += $3; mt += $4; yc += $5; yt += $6} END {printf "%.6f %.6f %.0f %.0f %.6f %.0f", tc, mc, tt, mt, yc, yt}'
}

cursor_spend() {
    local token=$1 segment subject user start end config csv_file today
    [[ -r "$pricing_cache" && -r "$supplement_cache" ]] || { printf '0 0 0 0 0 0'; return; }
    segment=$(printf '%s' "$token" | cut -d. -f2 | tr '_-' '/+')
    while (( ${#segment} % 4 )); do segment="${segment}="; done
    subject=$(printf '%s' "$segment" | base64 -d 2>/dev/null | jq -r '.sub // empty')
    user=${subject#*|}
    [[ -n "$user" ]] || { printf '0 0 0 0 0 0'; return; }
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
        printf '0 0 0 0 0 0'
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

totals = [0.0, 0.0, 0, 0, 0.0, 0]
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
yesterday_day = (datetime.date.fromisoformat(display_day) - datetime.timedelta(days=1)).isoformat()
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
        if local_day(row.get("Date") or "") == yesterday_day:
            totals[4] += cost
            totals[5] += tokens
print(f"{totals[0]:.6f} {totals[1]:.6f} {totals[2]} {totals[3]} {totals[4]:.6f} {totals[5]}", end="")
PY
    rm -f "$config" "$csv_file"
}

claude() {
    local file token body session weekly plan today_cost month_cost today_tokens month_tokens yesterday_cost yesterday_tokens session_reset weekly_reset
    file=$HOME/.claude/.credentials.json
    [[ -r "$file" ]] || return
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$file")
    [[ -n "$token" ]] || return
    body=$(request "$token" https://api.anthropic.com/api/oauth/usage GET 'Accept: application/json' 'anthropic-beta: oauth-2025-04-20' 'User-Agent: claude-code/2.1.69')
    session=$(jq -r '.five_hour.utilization // empty' <<< "$body")
    weekly=$(jq -r '.seven_day.utilization // empty' <<< "$body")
    session_reset=$(to_epoch "$(jq -r '.five_hour.resets_at // empty' <<< "$body")")
    weekly_reset=$(to_epoch "$(jq -r '.seven_day.resets_at // empty' <<< "$body")")
    plan=$(format_plan "$(jq -r '.claudeAiOauth.subscriptionType // empty' "$file")")
    read -r today_cost month_cost today_tokens month_tokens yesterday_cost yesterday_tokens <<< "$(claude_spend)"
    [[ "$session" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit claude Session "$session" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens" "$yesterday_cost" "$yesterday_tokens" "$plan" false "$session_reset"
    [[ "$weekly" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit claude Weekly "$weekly" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens" "$yesterday_cost" "$yesterday_tokens" "$plan" false "$weekly_reset"
}

codex() {
    local file token account body session weekly plan today_cost month_cost today_tokens month_tokens yesterday_cost yesterday_tokens session_reset weekly_reset
    file=$HOME/.codex/auth.json
    [[ -r "$file" ]] || file=$HOME/.config/codex/auth.json
    [[ -r "$file" ]] || return
    token=$(jq -r '.tokens.access_token // empty' "$file")
    account=$(jq -r '.tokens.account_id // empty' "$file")
    [[ -n "$token" ]] || return
    body=$(request "$token" https://chatgpt.com/backend-api/wham/usage GET 'Accept: application/json' "ChatGPT-Account-Id: $account")
    session=$(jq -r '.rate_limit.primary_window.used_percent // empty' <<< "$body")
    weekly=$(jq -r '.rate_limit.secondary_window.used_percent // empty' <<< "$body")
    session_reset=$(codex_window_reset "$(jq -c '.rate_limit.primary_window // {}' <<< "$body")")
    weekly_reset=$(codex_window_reset "$(jq -c '.rate_limit.secondary_window // {}' <<< "$body")")
    plan=$(format_plan "$(jq -r '.plan_type // empty' <<< "$body")")
    read -r today_cost month_cost today_tokens month_tokens yesterday_cost yesterday_tokens <<< "$(codex_spend)"
    [[ "$session" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit codex Session "$session" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens" "$yesterday_cost" "$yesterday_tokens" "$plan" false "$session_reset"
    [[ "$weekly" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit codex Weekly "$weekly" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens" "$yesterday_cost" "$yesterday_tokens" "$plan" false "$weekly_reset"
}

# @note codex windows carry reset_at (epoch seconds) or reset_after_seconds
codex_window_reset() {
    jq -r 'if (.reset_at // empty) != null then (.reset_at | floor)
           elif (.reset_after_seconds // empty) != null then (now + .reset_after_seconds | floor)
           else 0 end' <<< "$1" 2>/dev/null || printf '0'
}

cursor() {
    command -v sqlite3 >/dev/null || return
    command -v python >/dev/null || return
    local file token body plan_body total auto api plan today_cost month_cost today_tokens month_tokens yesterday_cost yesterday_tokens cycle_reset
    for file in "${XDG_CONFIG_HOME:-$HOME/.config}/Cursor/User/globalStorage/state.vscdb" "${XDG_CONFIG_HOME:-$HOME/.config}/cursor/User/globalStorage/state.vscdb"; do
        [[ -r "$file" ]] && break
    done
    [[ -r "$file" ]] || return
    token=$(sqlite3 -readonly "$file" "SELECT value FROM ItemTable WHERE key='cursorAuth/accessToken' LIMIT 1;" 2>/dev/null)
    [[ -n "$token" ]] || return
    body=$(request "$token" https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage POST 'Content-Type: application/json' 'Connect-Protocol-Version: 1')
    plan_body=$(request "$token" https://api2.cursor.sh/aiserver.v1.DashboardService/GetPlanInfo POST 'Content-Type: application/json' 'Connect-Protocol-Version: 1')
    total=$(jq -r '.planUsage.totalPercentUsed // empty' <<< "$body")
    auto=$(jq -r '.planUsage.autoPercentUsed // empty' <<< "$body")
    api=$(jq -r '.planUsage.apiPercentUsed // empty' <<< "$body")
    # @note billingCycleEnd is an epoch-milliseconds string at the response root
    cycle_reset=$(jq -r '((.billingCycleEnd // 0) | tonumber) / 1000 | floor' <<< "$body" 2>/dev/null || printf '0')
    plan=$(format_plan "$(jq -r '.planInfo.planName // empty' <<< "$plan_body")")
    read -r today_cost month_cost today_tokens month_tokens yesterday_cost yesterday_tokens <<< "$(cursor_spend "$token")"
    [[ "$total" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit cursor Total "$total" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens" "$yesterday_cost" "$yesterday_tokens" "$plan" false "$cycle_reset"
    [[ "$auto" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit cursor Auto "$auto" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens" "$yesterday_cost" "$yesterday_tokens" "$plan" false "$cycle_reset"
    [[ "$api" =~ ^[0-9]+([.][0-9]+)?$ ]] && emit cursor API "$api" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens" "$yesterday_cost" "$yesterday_tokens" "$plan" false "$cycle_reset"
}

opencode_spend() {
    local data_dir today yesterday cutoff
    data_dir=${OPENCODE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/opencode}
    today=$(date +%F)
    yesterday=$(date -d yesterday +%F)
    cutoff=$(date -d '29 days ago 00:00' +%s)000
    find "$data_dir" -maxdepth 1 -type f -name 'opencode*.db' -print0 2>/dev/null |
        while IFS= read -r -d '' file; do
            sqlite3 -readonly -separator $'\t' "$file" "SELECT strftime('%Y-%m-%d', time_created / 1000, 'unixepoch', 'localtime'), COALESCE(json_extract(data, '$.cost'), 0), COALESCE(json_extract(data, '$.tokens.total'), 0) FROM message WHERE time_created >= $cutoff AND json_valid(data) AND json_extract(data, '$.role') = 'assistant' AND json_extract(data, '$.providerID') IN ('opencode', 'opencode-go');" 2>/dev/null
        done | awk -F '\t' -v today="$today" -v yesterday="$yesterday" '{monthCost += $2; monthTokens += $3; if ($1 == today) { todayCost += $2; todayTokens += $3 } if ($1 == yesterday) { yesterdayCost += $2; yesterdayTokens += $3 }} END {printf "%.6f %.6f %.0f %.0f %.6f %.0f", todayCost, monthCost, todayTokens, monthTokens, yesterdayCost, yesterdayTokens}'
}

opencode() {
    local data_dir file go_key api_key body rolling weekly monthly plan today_cost month_cost today_tokens month_tokens yesterday_cost yesterday_tokens rolling_reset weekly_reset monthly_reset
    data_dir=${OPENCODE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/opencode}
    file=$data_dir/auth.json
    [[ -r "$file" ]] || return
    go_key=$(jq -r '."opencode-go".key // empty' "$file")
    api_key=$(jq -r '.opencode.key // empty' "$file")
    read -r today_cost month_cost today_tokens month_tokens yesterday_cost yesterday_tokens <<< "$(opencode_spend)"
    if [[ -z "$go_key" ]]; then
        [[ -n "$api_key" ]] && emit opencode Usage 0 "$today_cost" "$month_cost" "$today_tokens" "$month_tokens" "$yesterday_cost" "$yesterday_tokens" "API (Free)" true
        return
    fi
    body=$(request "$go_key" https://opencode.ai/zen/go/v1/usage GET 'Accept: application/json')
    rolling=$(jq -r '.usage.rolling.percent // empty' <<< "$body")
    weekly=$(jq -r '.usage.weekly.percent // empty' <<< "$body")
    monthly=$(jq -r '.usage.monthly.percent // empty' <<< "$body")
    rolling_reset=$(to_epoch "$(jq -r '.usage.rolling.resetsAt // empty' <<< "$body")")
    weekly_reset=$(to_epoch "$(jq -r '.usage.weekly.resetsAt // empty' <<< "$body")")
    monthly_reset=$(to_epoch "$(jq -r '.usage.monthly.resetsAt // empty' <<< "$body")")
    plan="API (Go)"
    local emitted=0
    [[ "$rolling" =~ ^[0-9]+([.][0-9]+)?$ ]] && { emit opencode Session "$rolling" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens" "$yesterday_cost" "$yesterday_tokens" "$plan" false "$rolling_reset"; emitted=1; }
    [[ "$weekly" =~ ^[0-9]+([.][0-9]+)?$ ]] && { emit opencode Weekly "$weekly" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens" "$yesterday_cost" "$yesterday_tokens" "$plan" false "$weekly_reset"; emitted=1; }
    [[ "$monthly" =~ ^[0-9]+([.][0-9]+)?$ ]] && { emit opencode Monthly "$monthly" "$today_cost" "$month_cost" "$today_tokens" "$month_tokens" "$yesterday_cost" "$yesterday_tokens" "$plan" false "$monthly_reset"; emitted=1; }
    # @note go key present but no active subscription windows — still show local spend
    (( emitted )) || emit opencode Usage 0 "$today_cost" "$month_cost" "$today_tokens" "$month_tokens" "$yesterday_cost" "$yesterday_tokens" "API (Free)" true
}

# @note pooled quota buckets from RetrieveUserQuotaSummary (openusage parity)
antigravity_summary_emit() {
    local body=$1 plan=$2 emitted=0 used reset_iso
    local -a order=(gemini-5h:Session gemini-weekly:Weekly 3p-5h:Claude 3p-weekly:"Claude Weekly")
    local spec bucket label
    for spec in "${order[@]}"; do
        bucket=${spec%%:*}
        label=${spec#*:}
        read -r used reset_iso <<< "$(jq -r --arg id "$bucket" '
            ((.response.groups // .groups // []) | map(.buckets // []) | add // [])
            | map(select(.bucketId == $id and (.remainingFraction | type == "number")))
            | first | if . == null then empty else [((1 - .remainingFraction) * 100), (.resetTime // "")] | @tsv end
        ' <<< "$body" 2>/dev/null)" || true
        [[ "$used" =~ ^[0-9]+([.][0-9]+)?$ ]] || continue
        emit antigravity "$label" "$used" 0 0 0 0 0 0 "$plan" false "$(to_epoch "$reset_iso")"
        emitted=1
    done
    (( emitted ))
}

antigravity_models_emit() {
    local body=$1 plan=$2
    local gemini gemini_reset claude claude_reset
    read -r gemini gemini_reset claude claude_reset <<< "$(jq -r '
        [.models // {} | to_entries[]
          | select(.value.isInternal != true)
          | ((.value.displayName // .value.label // "") | ascii_downcase) as $label
          | select($label != "")
          | [($label | test("gemini")), (.value.quotaInfo.remainingFraction // 0), (.value.quotaInfo.resetTime // "")]]
        | reduce .[] as $row ({g:null,gr:"",c:null,cr:""};
            if $row[0] then (if .g == null or $row[1] < .g then {g:$row[1],gr:$row[2],c:.c,cr:.cr} else . end)
            else (if .c == null or $row[1] < .c then {c:$row[1],cr:$row[2],g:.g,gr:.gr} else . end) end)
        | [(.g // empty), (.gr // ""), (.c // empty), (.cr // "")] | @tsv
    ' <<< "$body" 2>/dev/null)"
    local emitted=0
    if [[ "$gemini" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        emit antigravity Session "$(jq -n --argjson f "$gemini" '(1 - $f) * 100')" 0 0 0 0 0 0 "$plan" false "$(to_epoch "$gemini_reset")"
        emitted=1
    fi
    if [[ "$claude" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        emit antigravity Claude "$(jq -n --argjson f "$claude" '(1 - $f) * 100')" 0 0 0 0 0 0 "$plan" false "$(to_epoch "$claude_reset")"
        emitted=1
    fi
    (( emitted ))
}

antigravity_ls_call() {
    local scheme=$1 port=$2 csrf=$3 method=$4
    local -a curl_args=(--silent --show-error --fail --max-time 5 --request POST
        --header 'Content-Type: application/json'
        --header 'Connect-Protocol-Version: 1'
        --header "x-codeium-csrf-token: $csrf"
        --data '{"metadata":{"ideName":"antigravity","extensionName":"antigravity","ideVersion":"unknown","locale":"en"}}')
    [[ $scheme == https ]] && curl_args+=(-k)
    curl "${curl_args[@]}" "$scheme://127.0.0.1:$port/exa.language_server_pb.LanguageServerService/$method" 2>/dev/null || true
}

antigravity_from_ls() {
    local plan=$1 pid csrf ports port scheme summary status tier
    for pid in $(pgrep -f '[l]anguage_server' 2>/dev/null); do
        grep -zaq antigravity "/proc/$pid/cmdline" 2>/dev/null || continue
        csrf=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | awk 'f { print; exit } $0 == "--csrf_token" { f = 1 }')
        [[ -n "$csrf" ]] || continue
        ports=$(ss -ltnpH 2>/dev/null | awk -v pid="$pid" '
            index($0, "pid=" pid ",") {
                if (match($0, /127\.[0-9.]+:[0-9]+/)) print substr($0, RSTART, RLENGTH)
            }' | awk -F: '{print $NF}' | sort -nu)
        for port in $ports; do
            for scheme in https http; do
                summary=$(antigravity_ls_call "$scheme" "$port" "$csrf" RetrieveUserQuotaSummary)
                [[ -n "$summary" ]] || continue
                status=$(antigravity_ls_call "$scheme" "$port" "$csrf" GetUserStatus)
                tier=$(jq -r '.userStatus.userTier.name // .userTier.name // .userStatus.planStatus.planInfo.planName // .planStatus.planInfo.planName // empty' <<< "$status" 2>/dev/null)
                [[ -n "$tier" ]] && plan=$(format_plan "$tier")
                if antigravity_summary_emit "$summary" "$plan"; then
                    return 0
                fi
            done
        done
    done
    return 1
}

antigravity_oauth_client() {
    # @note pull installed-app oauth client from the local antigravity binary — never ship these in git
    local cache=$cache_dir/antigravity-oauth-client.tsv client_id client_secret bin
    if [[ -r "$cache" ]]; then
        IFS=$'\t' read -r client_id client_secret < "$cache"
        [[ -n "$client_id" && -n "$client_secret" ]] && { printf '%s\t%s' "$client_id" "$client_secret"; return 0; }
    fi
    for bin in \
        /opt/Antigravity/resources/bin/language_server \
        /usr/share/antigravity/resources/bin/language_server \
        /usr/lib/antigravity/resources/bin/language_server \
        "${ANTIGRAVITY_LANGUAGE_SERVER:-}"; do
        [[ -n "$bin" && -r "$bin" ]] || continue
        read -r client_id client_secret <<< "$(python - "$bin" <<'PY'
import re, sys
data = open(sys.argv[1], "rb").read()
# @note patterns split so the repo never contains a literal oauth client id/secret needle
ids = re.findall(rb"[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com", data)
sec_pat = ("GOC" + "SPX-[A-Za-z0-9_-]+").encode()
secs = re.findall(sec_pat, data)
if not ids or not secs:
    raise SystemExit(1)
print(ids[0].decode(), secs[0].decode())
PY
)" || continue
        [[ -n "$client_id" && -n "$client_secret" ]] || continue
        printf '%s\t%s\n' "$client_id" "$client_secret" > "$cache"
        chmod 600 "$cache"
        printf '%s\t%s' "$client_id" "$client_secret"
        return 0
    done
    return 1
}

antigravity_refresh_token() {
    local refresh=$1 cache=$cache_dir/antigravity-access.json now access expires client_id client_secret
    now=$(date +%s)
    if [[ -r "$cache" ]]; then
        access=$(jq -r --argjson now "$now" 'select(.expiresAt > $now + 60) | .accessToken // empty' "$cache" 2>/dev/null)
        [[ -n "$access" ]] && { printf '%s' "$access"; return 0; }
    fi
    IFS=$'\t' read -r client_id client_secret <<< "$(antigravity_oauth_client)" || return 1
    local body
    body=$(curl --silent --show-error --fail --max-time 15 \
        --data-urlencode "client_id=$client_id" \
        --data-urlencode "client_secret=$client_secret" \
        --data-urlencode "refresh_token=$refresh" \
        --data-urlencode 'grant_type=refresh_token' \
        https://oauth2.googleapis.com/token 2>/dev/null) || return 1
    access=$(jq -r '.access_token // empty' <<< "$body")
    expires=$(jq -r '.expires_in // 3600' <<< "$body")
    [[ -n "$access" ]] || return 1
    jq -cn --arg token "$access" --argjson now "$now" --argjson expires "$expires" \
        '{accessToken:$token,expiresAt:($now + $expires)}' > "$cache"
    chmod 600 "$cache"
    printf '%s' "$access"
}

antigravity_cloud_post() {
    local token=$1 path=$2 base body
    for base in https://daily-cloudcode-pa.googleapis.com https://cloudcode-pa.googleapis.com; do
        body=$(curl --silent --show-error --fail --max-time 15 \
            --request POST --data '{}' \
            --header "Authorization: Bearer $token" \
            --header 'Content-Type: application/json' \
            --header 'Accept: application/json' \
            --header 'User-Agent: antigravity' \
            "$base$path" 2>/dev/null) || true
        [[ -n "$body" ]] && { printf '%s' "$body"; return 0; }
    done
    return 1
}

antigravity_from_cloud() {
    local plan=$1 file refresh token summary models
    file=${OPENCODE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/opencode}/antigravity-accounts.json
    [[ -r "$file" ]] || return 1
    refresh=$(jq -r '.accounts[.activeIndex].refreshToken // .accounts[0].refreshToken // empty' "$file")
    [[ -n "$refresh" ]] || return 1
    token=$(antigravity_refresh_token "$refresh") || return 1
    summary=$(antigravity_cloud_post "$token" /v1internal:retrieveUserQuotaSummary) || true
    if [[ -n "$summary" ]] && antigravity_summary_emit "$summary" "$plan"; then
        return 0
    fi
    models=$(antigravity_cloud_post "$token" /v1internal:fetchAvailableModels) || true
    [[ -n "$models" ]] && antigravity_models_emit "$models" "$plan"
}

antigravity() {
    local file plan=""
    file=${OPENCODE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/opencode}/antigravity-accounts.json
    if [[ -r "$file" ]]; then
        plan=$(format_plan "$(jq -r '.accounts[.activeIndex].tier // .accounts[0].tier // empty' "$file")")
    fi
    antigravity_from_ls "$plan" && return
    antigravity_from_cloud "$plan" && return
    [[ -n "$plan" ]] && emit antigravity Account 0 0 0 0 0 0 0 "$plan" true
}

# @note keep last-good rows when a provider's api fails this refresh (timeout/outage)
provider_still_configured() {
    case "$1" in
        claude) [[ -r "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json" || -r "$HOME/.claude/.credentials.json" ]] ;;
        codex) [[ -r "$HOME/.codex/auth.json" || -r "$HOME/.config/codex/auth.json" ]] ;;
        cursor)
            [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/Cursor/User/globalStorage/state.vscdb" \
                || -r "${XDG_CONFIG_HOME:-$HOME/.config}/cursor/User/globalStorage/state.vscdb" ]]
            ;;
        antigravity)
            [[ -r "${OPENCODE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/opencode}/antigravity-accounts.json" ]] \
                || pgrep -f '[l]anguage_server' >/dev/null 2>&1
            ;;
        opencode) [[ -r "${OPENCODE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/opencode}/auth.json" ]] ;;
        *) return 1 ;;
    esac
}

merge_stale_providers() {
    local fresh=$1 stale=$2 present id line
    [[ -r "$stale" && -s "$fresh" ]] || return 0
    present=$(jq -r '.id // empty' "$fresh" 2>/dev/null | sort -u | paste -sd, -)
    present=",${present},"
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        id=$(jq -r '.id // empty' <<< "$line" 2>/dev/null) || continue
        [[ -n "$id" ]] || continue
        enabled_provider "$id" || continue
        provider_still_configured "$id" || continue
        [[ "$present" == *",$id,"* ]] && continue
        printf '%s\n' "$line"
        present="${present}${id},"
    done < "$stale" >> "$fresh"
}

usage_tmp=$(mktemp "$cache_dir/usage.XXXXXX")
{
    enabled_provider claude && claude
    enabled_provider codex && codex
    enabled_provider cursor && cursor
    enabled_provider antigravity && antigravity
    enabled_provider opencode && opencode
} > "$usage_tmp"

if [[ -s "$usage_tmp" ]]; then
    merge_stale_providers "$usage_tmp" "$usage_cache"
    # @note recover providers wiped by an earlier partial refresh before stale-merge existed
    merge_stale_providers "$usage_tmp" "$cache_dir/usage-v9-$cache_key.jsonl"
    merge_stale_providers "$usage_tmp" "$cache_dir/usage-v8-$cache_key.jsonl"
    mv "$usage_tmp" "$usage_cache"
else
    rm -f "$usage_tmp"
fi

[[ -r "$usage_cache" ]] && cat "$usage_cache"
