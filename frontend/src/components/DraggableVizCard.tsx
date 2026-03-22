import { useCallback, useLayoutEffect, useRef } from 'react'
import Draggable from 'react-draggable'
import type { RefObject } from 'react'
import type { Visualization } from '../types'
import { VisualizationRouter } from './VisualizationRouter'
import type { CardBounds, PortSide, PortRef } from './VizCardEdges'

const PORT_SIDES: PortSide[] = ['n', 'e', 's', 'w']

interface Props {
  cardId: string
  visualization: Visualization
  x: number
  y: number
  z: number
  mapHighlight: boolean
  exiting: boolean
  snapTarget: PortRef | null
  canvasRef: RefObject<HTMLElement | null>
  onCardBounds?: (id: string, bounds: CardBounds) => void
  onPortPointerDown: (side: PortSide, ev: React.PointerEvent) => void
  onDrag: (id: string, x: number, y: number) => void
  onDragStart: (id: string) => void
  onDismiss: (id: string) => void
  onExitAnimationEnd: (id: string) => void
}

function vizTitle(v: Visualization): string {
  if (v.title) return v.title
  switch (v.type) {
    case 'earthquake_map':
      return 'Earthquake map'
    case 'line_chart':
      return 'Chart'
    case 'stat_card':
      return 'Statistics'
    case 'location_map':
      return 'Location'
    case 'weather_card':
      return 'Weather'
    case 'document_excerpt':
      return 'Documents'
    default:
      return 'Visualization'
  }
}

function portLabel(side: PortSide): string {
  switch (side) {
    case 'n':
      return 'Connect from top'
    case 'e':
      return 'Connect from right'
    case 's':
      return 'Connect from bottom'
    case 'w':
      return 'Connect from left'
  }
}

export function DraggableVizCard({
  cardId,
  visualization,
  x,
  y,
  z,
  mapHighlight,
  exiting,
  snapTarget,
  canvasRef,
  onCardBounds,
  onPortPointerDown,
  onDrag,
  onDragStart,
  onDismiss,
  onExitAnimationEnd,
}: Props) {
  const title = vizTitle(visualization)
  const shellRef = useRef<HTMLDivElement>(null)
  const innerRef = useRef<HTMLDivElement>(null)

  const reportGeometry = useCallback(() => {
    if (!onCardBounds) return
    const canvas = canvasRef.current
    const inner = innerRef.current
    if (!canvas || !inner) return
    const cr = canvas.getBoundingClientRect()
    const er = inner.getBoundingClientRect()
    onCardBounds(cardId, {
      left: er.left - cr.left,
      top: er.top - cr.top,
      width: er.width,
      height: er.height,
    })
  }, [canvasRef, cardId, onCardBounds])

  useLayoutEffect(() => {
    reportGeometry()
  }, [x, y, visualization, exiting, reportGeometry])

  useLayoutEffect(() => {
    const inner = innerRef.current
    if (!inner) return
    const ro = new ResizeObserver(() => reportGeometry())
    ro.observe(inner)
    window.addEventListener('resize', reportGeometry)
    return () => {
      ro.disconnect()
      window.removeEventListener('resize', reportGeometry)
    }
  }, [reportGeometry])

  const handleAnimationEnd = (e: React.AnimationEvent<HTMLDivElement>) => {
    if (!exiting) return
    const names = e.animationName.split(',').map((n) => n.trim())
    if (!names.some((n) => n.includes('viz-card-exit'))) return
    onExitAnimationEnd(cardId)
  }

  const rootClass = [
    'viz-card-root',
    mapHighlight ? 'viz-card--map-latest' : '',
    exiting ? 'viz-card--exit' : 'viz-card--enter',
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <Draggable
      nodeRef={shellRef}
      handle=".viz-card-drag-handle"
      position={{ x, y }}
      bounds="parent"
      cancel=".viz-card-port"
      onStart={() => onDragStart(cardId)}
      onDrag={(_, data) => onDrag(cardId, data.x, data.y)}
      onStop={(_, data) => {
        onDrag(cardId, data.x, data.y)
        reportGeometry()
      }}
    >
      <div ref={shellRef} className="viz-card-draggable-shell" style={{ zIndex: z }}>
        <div
          ref={innerRef}
          data-viz-card-id={cardId}
          className={rootClass}
          onAnimationEnd={handleAnimationEnd}
        >
          {PORT_SIDES.map((side) => {
            const isSnap =
              snapTarget?.cardId === cardId && snapTarget.side === side
            return (
              <button
                key={side}
                type="button"
                className={`viz-card-port viz-card-port--${side}${isSnap ? ' viz-card-port--snap' : ''}`}
                aria-label={portLabel(side)}
                onPointerDown={(ev) => {
                  ev.preventDefault()
                  ev.stopPropagation()
                  onPortPointerDown(side, ev)
                }}
              />
            )
          })}
          <button
            type="button"
            className="viz-card-close"
            aria-label="Dismiss visualization"
            onClick={(e) => {
              e.stopPropagation()
              onDismiss(cardId)
            }}
          >
            ×
          </button>
          <div className="viz-card-drag-handle" title="Drag to move">
            <span className="viz-card-drag-grip" aria-hidden="true" />
            <span className="viz-card-drag-title">{title}</span>
          </div>
          <div className="viz-card-body">
            <VisualizationRouter visualization={visualization} />
          </div>
        </div>
      </div>
    </Draggable>
  )
}
