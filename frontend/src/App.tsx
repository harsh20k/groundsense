import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { invokeFormatter } from './api'
import { DraggableVizCard } from './components/DraggableVizCard'
import { MarkdownMessage } from './components/MarkdownMessage'
import { VizCardEdges, type CardCenter, type VizEdge } from './components/VizCardEdges'
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
  const [cardCenters, setCardCenters] = useState<Record<string, CardCenter>>({})
  const [input, setInput] = useState('')
  const [sessionId, setSessionId] = useState<string | undefined>(undefined)
  const [loading, setLoading] = useState(false)
  const maxZRef = useRef(1)
  const canvasRef = useRef<HTMLElement>(null)
  const messagesScrollRef = useRef<HTMLDivElement>(null)

  const latestMapOrder = useMemo(() => {
    const orders = vizCards
      .filter((c) => isMapVisualization(c.visualization))
      .map((c) => messageOrder(c.messageId))
    return orders.length ? Math.max(...orders) : 0
  }, [vizCards])

  useEffect(() => {
    const el = messagesScrollRef.current
    if (!el) return
    el.scrollTop = el.scrollHeight
  }, [messages, loading])

  const handleCardGeometry = useCallback((id: string, center: CardCenter) => {
    setCardCenters((prev) => {
      const p = prev[id]
      if (p && p.x === center.x && p.y === center.y) return prev
      return { ...prev, [id]: center }
    })
  }, [])

  const handleDrag = useCallback((id: string, x: number, y: number) => {
    setVizCards((prev) => prev.map((c) => (c.id === id ? { ...c, x, y } : c)))
  }, [])

  const handleDragStart = useCallback((id: string) => {
    maxZRef.current += 1
    const z = maxZRef.current
    setVizCards((prev) => prev.map((c) => (c.id === id ? { ...c, z } : c)))
  }, [])

  const handleDismissCard = useCallback((id: string) => {
    setVizCards((prev) => prev.filter((c) => c.id !== id))
    setCardEdges((prev) => prev.filter((e) => e.from !== id && e.to !== id))
    setCardCenters((prev) => {
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
        const newCardId = `v-${asstId}`
        setVizCards((prev) => {
          const n = prev.length
          maxZRef.current += 1
          const newCard: VizCardModel = {
            id: newCardId,
            messageId: asstId,
            visualization: res.visualization,
            x: 40 + (n % 8) * 26,
            y: 48 + (n % 5) * 24,
            z: maxZRef.current,
          }
          if (prev.length > 0) {
            const from = prev[prev.length - 1].id
            queueMicrotask(() =>
              setCardEdges((edges) => [
                ...edges,
                { id: nextEdgeId(), from, to: newCardId },
              ]),
            )
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
          <VizCardEdges edges={cardEdges} centers={cardCenters} />
          {vizCards.map((card) => (
            <DraggableVizCard
              key={card.id}
              cardId={card.id}
              visualization={card.visualization}
              x={card.x}
              y={card.y}
              z={card.z}
              mapHighlight={
                isMapVisualization(card.visualization) &&
                messageOrder(card.messageId) === latestMapOrder &&
                latestMapOrder > 0
              }
              canvasRef={canvasRef}
              onCardGeometry={handleCardGeometry}
              onDrag={handleDrag}
              onDragStart={handleDragStart}
              onDismiss={handleDismissCard}
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
                Ask a question below. Visualizations appear as movable cards on the canvas.
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
