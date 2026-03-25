import { useCallback, useLayoutEffect, useRef } from 'react'
import Draggable from 'react-draggable'
import type { CSSProperties, RefObject } from 'react'
import type { Visualization } from '../types'
import { VisualizationRouter } from './VisualizationRouter'
import type { CardBounds, PortSide, PortRef } from './VizCardEdges'

const PORT_SIDES: PortSide[] = ['n', 'e', 's', 'w']

/** Min/max card size (px) when resizing. */
const CARD_MIN_W = 260
const CARD_MIN_H = 180
const CARD_MAX_W = 920
const CARD_MAX_H = 720
const CANVAS_EDGE_MARGIN = 8

function clampCardSize(
  w: number,
  h: number,
  canvas: DOMRect | null,
  cardX: number,
  cardY: number,
): { w: number; h: number } {
  let nw = Math.min(CARD_MAX_W, Math.max(CARD_MIN_W, w))
  let nh = Math.min(CARD_MAX_H, Math.max(CARD_MIN_H, h))
  if (canvas) {
    const maxByCanvasW = canvas.width - cardX - CANVAS_EDGE_MARGIN
    const maxByCanvasH = canvas.height - cardY - CANVAS_EDGE_MARGIN
    if (maxByCanvasW >= CARD_MIN_W) nw = Math.min(nw, maxByCanvasW)
    if (maxByCanvasH >= CARD_MIN_H) nh = Math.min(nh, maxByCanvasH)
    nw = Math.max(CARD_MIN_W, nw)
    nh = Math.max(CARD_MIN_H, nh)
  }
  return { w: nw, h: nh }
}

interface Props {
  cardId: string
  visualization: Visualization
  x: number
  y: number
  z: number
  cardWidth?: number
  cardHeight?: number
  mapHighlight: boolean
  exiting: boolean
  snapTarget: PortRef | null
  canvasRef: RefObject<HTMLElement | null>
  onCardBounds?: (id: string, bounds: CardBounds) => void
  onPortPointerDown: (side: PortSide, ev: React.PointerEvent) => void
  onDrag: (id: string, x: number, y: number) => void
  onDragStart: (id: string) => void
  onResize: (id: string, width: number, height: number) => void
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
  cardWidth,
  cardHeight,
  mapHighlight,
  exiting,
  snapTarget,
  canvasRef,
  onCardBounds,
  onPortPointerDown,
  onDrag,
  onDragStart,
  onResize,
  onDismiss,
  onExitAnimationEnd,
}: Props) {
  const title = vizTitle(visualization)
  const shellRef = useRef<HTMLDivElement>(null)
  const innerRef = useRef<HTMLDivElement>(null)
  const hasExplicitSize =
    typeof cardWidth === 'number' && typeof cardHeight === 'number'

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
  }, [x, y, cardWidth, cardHeight, visualization, exiting, reportGeometry])

  const onResizePointerDown = useCallback(
    (ev: React.PointerEvent) => {
      if (!ev.isPrimary || exiting) return
      ev.preventDefault()
      ev.stopPropagation()
      onDragStart(cardId)
      const shell = shellRef.current
      const canvasEl = canvasRef.current
      if (!shell || !canvasEl) return
      const target = ev.currentTarget
      target.setPointerCapture(ev.pointerId)

      const cr = canvasEl.getBoundingClientRect()
      const sr = shell.getBoundingClientRect()
      const startW = cardWidth ?? sr.width
      const startH = cardHeight ?? sr.height
      const startClientX = ev.clientX
      const startClientY = ev.clientY
      const pointerId = ev.pointerId

      const onMove = (e: PointerEvent) => {
        if (e.pointerId !== pointerId) return
        const dw = e.clientX - startClientX
        const dh = e.clientY - startClientY
        const { w, h } = clampCardSize(
          startW + dw,
          startH + dh,
          cr,
          x,
          y,
        )
        onResize(cardId, w, h)
      }
      const onUp = (e: PointerEvent) => {
        if (e.pointerId !== pointerId) return
        window.removeEventListener('pointermove', onMove)
        window.removeEventListener('pointerup', onUp)
        window.removeEventListener('pointercancel', onUp)
        try {
          target.releasePointerCapture(pointerId)
        } catch {
          /* already released */
        }
        reportGeometry()
      }
      window.addEventListener('pointermove', onMove)
      window.addEventListener('pointerup', onUp)
      window.addEventListener('pointercancel', onUp)
    },
    [
      cardId,
      cardHeight,
      cardWidth,
      canvasRef,
      exiting,
      onDragStart,
      onResize,
      reportGeometry,
      x,
      y,
    ],
  )

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
    hasExplicitSize ? 'viz-card-root--sized' : '',
    mapHighlight ? 'viz-card--map-latest' : '',
    exiting ? 'viz-card--exit' : 'viz-card--enter',
  ]
    .filter(Boolean)
    .join(' ')

  const shellClass = [
    'viz-card-draggable-shell',
    hasExplicitSize ? 'viz-card-shell--sized' : '',
  ]
    .filter(Boolean)
    .join(' ')

  const shellStyle: CSSProperties = {
    zIndex: z,
    ...(hasExplicitSize
      ? {
          width: cardWidth,
          height: cardHeight,
          maxWidth: '100%',
        }
      : {}),
  }

  return (
    <Draggable
      nodeRef={shellRef}
      handle=".viz-card-drag-handle"
      position={{ x, y }}
      bounds="parent"
      cancel=".viz-card-port, .viz-card-resize-handle"
      onStart={() => onDragStart(cardId)}
      onDrag={(_, data) => onDrag(cardId, data.x, data.y)}
      onStop={(_, data) => {
        onDrag(cardId, data.x, data.y)
        reportGeometry()
      }}
    >
      <div ref={shellRef} className={shellClass} style={shellStyle}>
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
          <button
            type="button"
            className="viz-card-resize-handle"
            aria-label="Resize visualization"
            title="Drag to resize"
            onPointerDown={onResizePointerDown}
          >
            <svg
              className="viz-card-resize-icon"
              width="14"
              height="14"
              viewBox="0 0 14 14"
              aria-hidden="true"
            >
              <path
                d="M14 14H10M14 14V10M14 14L9 9M14 6v-4M10 2H6M6 6L2 2"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
              />
            </svg>
          </button>
        </div>
      </div>
    </Draggable>
  )
}
