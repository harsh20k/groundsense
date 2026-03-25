import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { invokeFormatter } from './api'
import { DraggableVizCard } from './components/DraggableVizCard'
import { MarkdownMessage } from './components/MarkdownMessage'
import {
  VizCardEdgeLayers,
  type CardBounds,
  type PortSide,
  type PortRef,
  type VizEdge,
  findNearestPort,
  edgeKey,
  portPoint,
} from './components/VizCardEdges'
import type { Visualization } from './types'
import { PRESET_QUERIES } from './presetQueries'
import './App.css'

type ChatRole = 'user' | 'assistant' | 'error'

interface ChatMessage {
  id: string
  role: ChatRole
  text: string
  visualization?: Visualization
}

interface VizCardModel {
  id: string
  messageId: string
  visualization: Visualization
  x: number
  y: number
  z: number
  /** User-resized size (px). Omitted = default CSS sizing on the shell. */
  width?: number
  height?: number
  exiting?: boolean
}

interface DraftState {
  fromCardId: string
  fromSide: PortSide
  startX: number
  startY: number
  currentX: number
  currentY: number
}

let idCounter = 0
function nextId(): string {
  idCounter += 1
  return `m-${idCounter}`
}

function messageOrder(id: string): number {
  const m = /^m-(\d+)$/.exec(id)
  return m ? parseInt(m[1], 10) : 0
}

function isMapVisualization(v: Visualization): boolean {
  return v.type === 'earthquake_map' || v.type === 'location_map'
}

let edgeCounter = 0
function nextEdgeId(): string {
  edgeCounter += 1
  return `edge-${edgeCounter}`
}

export default function App() {
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [vizCards, setVizCards] = useState<VizCardModel[]>([])
  const [cardEdges, setCardEdges] = useState<VizEdge[]>([])
  const [cardBounds, setCardBounds] = useState<Record<string, CardBounds>>({})
  const [draft, setDraft] = useState<DraftState | null>(null)
  const [snapHighlight, setSnapHighlight] = useState<PortRef | null>(null)
  const [input, setInput] = useState('')
  const [sessionId, setSessionId] = useState<string | undefined>(undefined)
  const [loading, setLoading] = useState(false)
  const maxZRef = useRef(1)
  const canvasRef = useRef<HTMLElement>(null)
  const messagesScrollRef = useRef<HTMLDivElement>(null)
  const cardBoundsRef = useRef(cardBounds)

  useEffect(() => {
    cardBoundsRef.current = cardBounds
  }, [cardBounds])

  const latestMapOrder = useMemo(() => {
    const orders = vizCards
      .filter((c) => !c.exiting && isMapVisualization(c.visualization))
      .map((c) => messageOrder(c.messageId))
    return orders.length ? Math.max(...orders) : 0
  }, [vizCards])

  useEffect(() => {
    const el = messagesScrollRef.current
    if (!el) return
    el.scrollTop = el.scrollHeight
  }, [messages, loading])

  const clientToCanvas = useCallback((clientX: number, clientY: number) => {
    const c = canvasRef.current
    if (!c) return { x: 0, y: 0 }
    const r = c.getBoundingClientRect()
    return { x: clientX - r.left, y: clientY - r.top }
  }, [])

  useEffect(() => {
    if (!draft) return

    const fromCardId = draft.fromCardId

    const onMove = (e: PointerEvent) => {
      const { x, y } = clientToCanvas(e.clientX, e.clientY)
      setDraft((d) => (d ? { ...d, currentX: x, currentY: y } : null))
      const near = findNearestPort(x, y, cardBoundsRef.current, {
        ignoreCardId: fromCardId,
      })
      setSnapHighlight(near)
    }

    let finished = false
    const finish = (e: PointerEvent) => {
      if (finished) return
      finished = true
      const { x, y } = clientToCanvas(e.clientX, e.clientY)
      const target = findNearestPort(x, y, cardBoundsRef.current, {
        ignoreCardId: fromCardId,
      })

      setDraft((currentDraft) => {
        if (
          currentDraft &&
          target &&
          target.cardId !== currentDraft.fromCardId
        ) {
          const newEdge: VizEdge = {
            id: nextEdgeId(),
            fromCardId: currentDraft.fromCardId,
            fromSide: currentDraft.fromSide,
            toCardId: target.cardId,
            toSide: target.side,
          }
          setCardEdges((prev) => {
            const k = edgeKey(newEdge)
            if (prev.some((ed) => edgeKey(ed) === k)) return prev
            return [...prev, newEdge]
          })
        }
        return null
      })
      setSnapHighlight(null)
      window.removeEventListener('pointermove', onMove)
      window.removeEventListener('pointerup', finish)
      window.removeEventListener('pointercancel', finish)
    }

    window.addEventListener('pointermove', onMove)
    window.addEventListener('pointerup', finish)
    window.addEventListener('pointercancel', finish)
    return () => {
      window.removeEventListener('pointermove', onMove)
      window.removeEventListener('pointerup', finish)
      window.removeEventListener('pointercancel', finish)
    }
  }, [draft, clientToCanvas])

  const handleCardBounds = useCallback((id: string, b: CardBounds) => {
    setCardBounds((prev) => {
      const p = prev[id]
      if (
        p &&
        p.left === b.left &&
        p.top === b.top &&
        p.width === b.width &&
        p.height === b.height
      ) {
        return prev
      }
      return { ...prev, [id]: b }
    })
  }, [])

  const handlePortPointerDown = useCallback(
    (cardId: string, side: PortSide, ev: React.PointerEvent) => {
      if (!ev.isPrimary) return
      const b = cardBoundsRef.current[cardId]
      if (!b) return
      const p = portPoint(b, side)
      setDraft({
        fromCardId: cardId,
        fromSide: side,
        startX: p.x,
        startY: p.y,
        currentX: p.x,
        currentY: p.y,
      })
      setSnapHighlight(null)
    },
    [],
  )

  const handleDrag = useCallback((id: string, x: number, y: number) => {
    setVizCards((prev) => prev.map((c) => (c.id === id ? { ...c, x, y } : c)))
  }, [])

  const handleDragStart = useCallback((id: string) => {
    maxZRef.current += 1
    const z = maxZRef.current
    setVizCards((prev) => prev.map((c) => (c.id === id ? { ...c, z } : c)))
  }, [])

  const handleResizeCard = useCallback((id: string, width: number, height: number) => {
    setVizCards((prev) =>
      prev.map((c) => (c.id === id ? { ...c, width, height } : c)),
    )
  }, [])

  const handleDismissCard = useCallback((id: string) => {
    setVizCards((prev) =>
      prev.map((c) => (c.id === id ? { ...c, exiting: true } : c)),
    )
  }, [])

  const handleExitAnimationEnd = useCallback((id: string) => {
    setVizCards((prev) => prev.filter((c) => c.id !== id))
    setCardEdges((prev) =>
      prev.filter((e) => e.fromCardId !== id && e.toCardId !== id),
    )
    setCardBounds((prev) => {
      if (!(id in prev)) return prev
      const next = { ...prev }
      delete next[id]
      return next
    })
  }, [])

  const send = useCallback(async () => {
    const query = input.trim()
    if (!query || loading) return

    setInput('')
    const userId = nextId()
    setMessages((prev) => [...prev, { id: userId, role: 'user', text: query }])
    setLoading(true)

    try {
      const res = await invokeFormatter(query, sessionId)
      setSessionId(res.session_id)
      const asstId = nextId()
      setMessages((prev) => [
        ...prev,
        {
          id: asstId,
          role: 'assistant',
          text: res.message || '(No text in response)',
          visualization: res.visualization,
        },
      ])
      if (res.visualization.type !== 'none') {
        setVizCards((prev) => {
          const n = prev.length
          maxZRef.current += 1
          const newCard: VizCardModel = {
            id: `v-${asstId}`,
            messageId: asstId,
            visualization: res.visualization,
            x: 40 + (n % 8) * 26,
            y: 48 + (n % 5) * 24,
            z: maxZRef.current,
          }
          return [...prev, newCard]
        })
      }
    } catch (e) {
      const text = e instanceof Error ? e.message : 'Request failed'
      setMessages((prev) => [...prev, { id: nextId(), role: 'error', text }])
    } finally {
      setLoading(false)
    }
  }, [input, loading, sessionId])

  const onKeyDown = (ev: React.KeyboardEvent) => {
    if (ev.key === 'Enter' && !ev.shiftKey) {
      ev.preventDefault()
      void send()
    }
  }

  const applyPreset = (query: string) => {
    setInput(query)
  }

  const draftLine = draft
    ? {
        x1: draft.startX,
        y1: draft.startY,
        side: draft.fromSide,
        x2: draft.currentX,
        y2: draft.currentY,
      }
    : null

  return (
    <div className="app">
      <header className="app-header">
        <div className="app-header-inner">
          <h1 className="app-title">GroundSense</h1>
          <p className="app-tagline">Earthquake Q&amp;A (prototype)</p>
        </div>
      </header>

      <div className="app-body">
        <main ref={canvasRef} className="viz-canvas" aria-label="Visualization canvas">
          <VizCardEdgeLayers edges={cardEdges} bounds={cardBounds} draftLine={draftLine} />
          {vizCards.map((card) => (
            <DraggableVizCard
              key={card.id}
              cardId={card.id}
              visualization={card.visualization}
              x={card.x}
              y={card.y}
              z={card.z}
              cardWidth={card.width}
              cardHeight={card.height}
              exiting={Boolean(card.exiting)}
              snapTarget={snapHighlight}
              mapHighlight={
                !card.exiting &&
                isMapVisualization(card.visualization) &&
                messageOrder(card.messageId) === latestMapOrder &&
                latestMapOrder > 0
              }
              canvasRef={canvasRef}
              onCardBounds={handleCardBounds}
              onPortPointerDown={(side, ev) => handlePortPointerDown(card.id, side, ev)}
              onDrag={handleDrag}
              onDragStart={handleDragStart}
              onResize={handleResizeCard}
              onDismiss={handleDismissCard}
              onExitAnimationEnd={handleExitAnimationEnd}
            />
          ))}
        </main>

        <aside className="chat-column" aria-label="Chat">
          <div
            ref={messagesScrollRef}
            className="chat-messages-scroll"
            role="log"
            aria-live="polite"
            aria-relevant="additions"
          >
            {messages.length === 0 && !loading ? (
              <p className="dock-hint">
                Ask a question below. Visualizations appear as movable cards on the canvas. Drag from
                the dots on card edges to link cards.
              </p>
            ) : null}
            {messages.map((m) => {
              if (m.role === 'user') {
                return (
                  <div key={m.id} className="msg msg-user chat-msg chat-msg-user">
                    {m.text}
                  </div>
                )
              }
              if (m.role === 'error') {
                return (
                  <div key={m.id} className="msg msg-error chat-msg">
                    {m.text}
                  </div>
                )
              }
              return (
                <div key={m.id} className="msg msg-assistant chat-msg">
                  <MarkdownMessage content={m.text} />
                </div>
              )
            })}
            {loading ? (
              <div className="chat-loading" role="status" aria-live="polite">
                <span className="spinner spinner--sm" aria-hidden="true" />
                <span>Calling agent…</span>
              </div>
            ) : null}
          </div>

          <div className="chat-column-footer">
            <div className="presets" role="toolbar" aria-label="Example queries">
              {PRESET_QUERIES.map((p) => (
                <button
                  key={p.id}
                  type="button"
                  className="preset-chip"
                  onClick={() => applyPreset(p.query)}
                >
                  {p.label}
                </button>
              ))}
            </div>

            <div className="composer" aria-busy={loading}>
              {sessionId ? (
                <p className="session-hint" title={sessionId}>
                  Session: {sessionId.slice(0, 24)}
                  {sessionId.length > 24 ? '…' : ''}
                </p>
              ) : null}
              <textarea
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={onKeyDown}
                placeholder="e.g. M4+ earthquakes near Vancouver in the last 7 days"
                disabled={loading}
                aria-label="Question"
                rows={2}
              />
              <div className="composer-actions">
                {loading ? (
                  <span className="loading-inline" role="status">
                    <span className="spinner spinner--sm" aria-hidden="true" />
                    <span className="loading-inline-label">Thinking…</span>
                  </span>
                ) : (
                  <span className="composer-actions-spacer" />
                )}
                <button type="button" onClick={() => void send()} disabled={loading || !input.trim()}>
                  Send
                </button>
              </div>
            </div>
          </div>
        </aside>
      </div>
    </div>
  )
}
