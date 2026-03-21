import { useRef } from 'react'
import Draggable from 'react-draggable'
import type { Visualization } from '../types'
import { VisualizationRouter } from './VisualizationRouter'

interface Props {
  cardId: string
  visualization: Visualization
  x: number
  y: number
  z: number
  mapHighlight: boolean
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
  onDrag,
  onDragStart,
  onDismiss,
}: Props) {
  const title = vizTitle(visualization)
  const nodeRef = useRef<HTMLDivElement>(null)

  return (
    <Draggable
      nodeRef={nodeRef}
      handle=".viz-card-drag-handle"
      position={{ x, y }}
      bounds="parent"
      onStart={() => onDragStart(cardId)}
      onDrag={(_, data) => onDrag(cardId, data.x, data.y)}
      onStop={(_, data) => onDrag(cardId, data.x, data.y)}
    >
      <div
        ref={nodeRef}
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
