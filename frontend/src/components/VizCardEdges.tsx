export interface VizEdge {
  id: string
  from: string
  to: string
}

export interface CardCenter {
  x: number
  y: number
}

interface Props {
  edges: VizEdge[]
  centers: Record<string, CardCenter>
}

function curvePath(x1: number, y1: number, x2: number, y2: number): string {
  const dx = x2 - x1
  const dy = y2 - y1
  const cx1 = x1 + dx * 0.35
  const cy1 = y1 + dy * 0.1
  const cx2 = x2 - dx * 0.35
  const cy2 = y2 - dy * 0.1
  return `M ${x1} ${y1} C ${cx1} ${cy1} ${cx2} ${cy2} ${x2} ${y2}`
}

export function VizCardEdges({ edges, centers }: Props) {
  return (
    <svg
      className="viz-card-edges"
      aria-hidden="true"
      width="100%"
      height="100%"
      preserveAspectRatio="none"
    >
      {edges.map((e) => {
        const a = centers[e.from]
        const b = centers[e.to]
        if (!a || !b) return null
        return (
          <path
            key={e.id}
            d={curvePath(a.x, a.y, b.x, b.y)}
            fill="none"
            stroke="var(--accent)"
            strokeWidth={1.5}
            strokeOpacity={0.4}
            strokeLinecap="round"
          />
        )
      })}
    </svg>
  )
}
