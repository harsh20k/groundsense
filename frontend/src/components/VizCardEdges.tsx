export type PortSide = 'n' | 'e' | 's' | 'w'

export interface CardBounds {
  left: number
  top: number
  width: number
  height: number
}

export interface VizEdge {
  id: string
  fromCardId: string
  fromSide: PortSide
  toCardId: string
  toSide: PortSide
}

export interface PortRef {
  cardId: string
  side: PortSide
}

const SNAP_PX = 28

export function portPoint(b: CardBounds, side: PortSide): { x: number; y: number } {
  const { left, top, width, height } = b
  switch (side) {
    case 'n':
      return { x: left + width / 2, y: top }
    case 'e':
      return { x: left + width, y: top + height / 2 }
    case 's':
      return { x: left + width / 2, y: top + height }
    case 'w':
      return { x: left, y: top + height / 2 }
  }
}

function normal(side: PortSide): { x: number; y: number } {
  switch (side) {
    case 'n':
      return { x: 0, y: -1 }
    case 'e':
      return { x: 1, y: 0 }
    case 's':
      return { x: 0, y: 1 }
    case 'w':
      return { x: -1, y: 0 }
  }
}

const CURVE_OFFSET = 44

function curvePathPortToPort(
  x1: number,
  y1: number,
  side1: PortSide,
  x2: number,
  y2: number,
  side2: PortSide,
): string {
  const n1 = normal(side1)
  const n2 = normal(side2)
  const cx1 = x1 + n1.x * CURVE_OFFSET
  const cy1 = y1 + n1.y * CURVE_OFFSET
  const cx2 = x2 + n2.x * CURVE_OFFSET
  const cy2 = y2 + n2.y * CURVE_OFFSET
  return `M ${x1} ${y1} C ${cx1} ${cy1} ${cx2} ${cy2} ${x2} ${y2}`
}

/** Draft wire from a port toward the pointer (Obsidian-style outbound curve). */
export function curvePathPortToPoint(x1: number, y1: number, side: PortSide, x2: number, y2: number): string {
  const n = normal(side)
  const cx1 = x1 + n.x * CURVE_OFFSET
  const cy1 = y1 + n.y * CURVE_OFFSET
  const midX = (x1 + x2) / 2
  const midY = (y1 + y2) / 2
  return `M ${x1} ${y1} C ${cx1} ${cy1} ${midX} ${midY} ${x2} ${y2}`
}

export function findNearestPort(
  canvasX: number,
  canvasY: number,
  bounds: Record<string, CardBounds>,
  opts?: { ignoreCardId?: string },
): PortRef | null {
  let best: PortRef | null = null
  let bestD = SNAP_PX
  const sides: PortSide[] = ['n', 'e', 's', 'w']
  for (const cardId of Object.keys(bounds)) {
    if (opts?.ignoreCardId && cardId === opts.ignoreCardId) continue
    const b = bounds[cardId]
    if (!b || b.width <= 0 || b.height <= 0) continue
    for (const side of sides) {
      const p = portPoint(b, side)
      const d = Math.hypot(canvasX - p.x, canvasY - p.y)
      if (d < bestD) {
        bestD = d
        best = { cardId, side }
      }
    }
  }
  return best
}

export function edgeKey(e: Omit<VizEdge, 'id'>): string {
  return `${e.fromCardId}:${e.fromSide}->${e.toCardId}:${e.toSide}`
}

interface LayersProps {
  edges: VizEdge[]
  bounds: Record<string, CardBounds>
  draftLine: null | { x1: number; y1: number; side: PortSide; x2: number; y2: number }
}

export function VizCardEdgeLayers({ edges, bounds, draftLine }: LayersProps) {
  return (
    <>
      <svg
        className="viz-card-edges"
        aria-hidden="true"
        width="100%"
        height="100%"
        preserveAspectRatio="none"
      >
        {edges.map((e) => {
          const b1 = bounds[e.fromCardId]
          const b2 = bounds[e.toCardId]
          if (!b1 || !b2) return null
          const a = portPoint(b1, e.fromSide)
          const b = portPoint(b2, e.toSide)
          return (
            <path
              key={e.id}
              d={curvePathPortToPort(a.x, a.y, e.fromSide, b.x, b.y, e.toSide)}
              fill="none"
              stroke="var(--accent)"
              strokeWidth={1.5}
              strokeOpacity={0.45}
              strokeLinecap="round"
            />
          )
        })}
      </svg>
      {draftLine ? (
        <svg
          className="viz-card-edges-draft"
          aria-hidden="true"
          width="100%"
          height="100%"
          preserveAspectRatio="none"
        >
          <path
            d={curvePathPortToPoint(draftLine.x1, draftLine.y1, draftLine.side, draftLine.x2, draftLine.y2)}
            fill="none"
            stroke="var(--accent)"
            strokeWidth={1.75}
            strokeOpacity={0.7}
            strokeLinecap="round"
            strokeDasharray="6 4"
          />
        </svg>
      ) : null}
    </>
  )
}
