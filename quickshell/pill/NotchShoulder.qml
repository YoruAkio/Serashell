import QtQuick
import QtQuick.Shapes

Item {
    id: shoulder

    property bool concaveLeft: true
    property int shoulderSize: 18
    property color fill: "black"

    implicitWidth: shoulderSize
    implicitHeight: shoulderSize

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: shoulder.fill
            pathHints: ShapePath.PathSolid | ShapePath.PathNonIntersecting
            startX: shoulder.concaveLeft ? shoulder.shoulderSize : 0
            startY: 0

            PathAngleArc {
                moveToStart: false
                centerX: shoulder.concaveLeft ? 0 : shoulder.shoulderSize
                centerY: shoulder.shoulderSize
                radiusX: shoulder.shoulderSize
                radiusY: shoulder.shoulderSize
                startAngle: shoulder.concaveLeft ? -90 : 180
                sweepAngle: 90
            }

            PathLine { x: shoulder.concaveLeft ? shoulder.shoulderSize : 0; y: 0 }
        }
    }
}
