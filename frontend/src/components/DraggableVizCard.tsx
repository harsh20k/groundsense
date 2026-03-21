import { useCallback, useLayoutEffect, useRef } from 'react'
import Draggable from 'react-draggable'
import type { RefObject } from 'react'
import type { Visualization } from '../types'
import { VisualizationRouter } from './VisualizationRouter'
import type { CardCenter } from './VizCardEdges'

interface Props {
  cardId: string
  visualization: Visualization
  x: number
  y: number
  z: number
  mapHighlight: boolean
  canvasRef: RefObject<HTMLElement | null>
  onCardGeometry?: (id: string, center: CardCenter) => void
  onDrag: (id: string, x: number, y: number) => void
  onDragStart: (id: string) => void
  onDismiss: (id: string) => void
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

export function DraggableVizCard({
  cardId,
  visualization,
  x,
  y,
  z,
  mapHighlight,
  canvasRef,
  onCardGeometry,
  onDrag,
  onDragStart,
  onDismiss,
}: Props) {
  const title = vizTitle(visualization)
  const nodeRef = useRef<HTMLDivElement>(null)

  const reportGeometry = useCallback(() => {
    if (!onCardGeometry) return
    const canvas = canvasRef.current
    const el = nodeRef.current
    if (!canvas || !el) return
    const cr = canvas.getBoundingClientRect()
    const er = el.getBoundingClientRect()
    onCardGeometry(cardId, {
      x: er.left - cr.left + er.width / 2,
      y: er.top - cr.top + er.height / 2,
    })
  }, [canvasRef, cardId, onCardGeometry])

  useLayoutEffect(() => {
    reportGeometry()
  }, [x, y, visualization, reportGeometry])

  useLayoutEffect(() => {
    const el = nodeRef.current
    if (!el) return
    const ro = new ResizeObserver(() => reportGeometry())
    ro.observe(el)
    window.addEventListener('resize', reportGeometry)
    return () => {
      ro.disconnect()
      window.removeEventListener('resize', reportGeometry)
    }
  }, [reportGeometry])

  return (
    <Draggable
      nodeRef={nodeRef}
      handle=".viz-card-drag-handle"
      position={{ x, y }}
      bounds="parent"
      onStart={() => onDragStart(cardId)}
      onDrag={(_, data) => onDrag(cardId, data.x, data.y)}
      onStop={(_, data) => {
        onDrag(cardId, data.x, data.y)
        reportGeometry()
      }}
    >
      <div
        ref={nodeRef}
        data-viz-card-id={cardId}
        className={`viz-card-root ${mapHighlight ? 'viz-card--map-latest' : ''}`}
        style={{ zIndex: z }}
      >
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
    </Draggable>
  )
}
