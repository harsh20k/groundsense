import { useCallback, useMemo, useRef, useState } from 'react'
import { invokeFormatter } from './api'
import { DraggableVizCard } from './components/DraggableVizCard'
import { MarkdownMessage } from './components/MarkdownMessage'
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

function splitLatestMessages(messages: ChatMessage[]) {
  const lastUserIndex = messages.reduce(
    (idx, m, i) => (m.role === 'user' ? i : idx),
    -1,
  )
  if (lastUserIndex < 0) {
    return {
      latestUser: null as ChatMessage | null,
      latestReply: null as ChatMessage | null,
      historyMessages: [] as ChatMessage[],
    }
  }
  const latestUser = messages[lastUserIndex]
  const latestReply =
    messages.slice(lastUserIndex + 1).find((m) => m.role === 'assistant' || m.role === 'error') ??
    null
  const historyMessages = messages.slice(0, lastUserIndex)
  return { latestUser, latestReply, historyMessages }
}

export default function App() {
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [vizCards, setVizCards] = useState<VizCardModel[]>([])
  const [input, setInput] = useState('')
  const [sessionId, setSessionId] = useState<string | undefined>(undefined)
  const [loading, setLoading] = useState(false)
  const [historyOpen, setHistoryOpen] = useState(false)
  const maxZRef = useRef(1)

  const { latestUser, latestReply, historyMessages } = useMemo(
    () => splitLatestMessages(messages),
    [messages],
  )

  const latestMapOrder = useMemo(() => {
    const orders = vizCards
      .filter((c) => isMapVisualization(c.visualization))
      .map((c) => messageOrder(c.messageId))
    return orders.length ? Math.max(...orders) : 0
  }, [vizCards])

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
  }, [])

  const send = useCallback(async () => {
    const query = input.trim()
    if (!query || loading) return

    setInput('')
    setHistoryOpen(false)
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
          return [
            ...prev,
            {
              id: `v-${asstId}`,
              messageId: asstId,
              visualization: res.visualization,
              x: 40 + (n % 8) * 26,
              y: 48 + (n % 5) * 24,
              z: maxZRef.current,
            },
          ]
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

      <main className="viz-canvas" aria-label="Visualization canvas">
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
            onDrag={handleDrag}
            onDragStart={handleDragStart}
            onDismiss={handleDismissCard}
          />
        ))}
      </main>

      <footer className="chat-dock">
        <div className="chat-dock-inner">
          <div className="latest-qa" aria-live="polite">
            {latestUser ? (
              <div className="msg msg-user latest-qa-user">{latestUser.text}</div>
            ) : (
              <p className="dock-hint">Ask a question below. Visualizations appear as movable cards.</p>
            )}
            {latestReply ? (
              latestReply.role === 'error' ? (
                <div className="msg msg-error latest-qa-answer">{latestReply.text}</div>
              ) : (
                <div className="msg msg-assistant latest-qa-answer">
                  <MarkdownMessage content={latestReply.text} />
                </div>
              )
            ) : null}
            {loading ? (
              <div className="latest-qa-loading" role="status" aria-live="polite">
                <span className="spinner spinner--sm" aria-hidden="true" />
                <span>Calling agent…</span>
              </div>
            ) : null}
          </div>

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

          {historyMessages.length > 0 ? (
            <div className="history-wrap">
              <button
                type="button"
                className="history-toggle"
                aria-expanded={historyOpen}
                onClick={() => setHistoryOpen((o) => !o)}
              >
                Previous messages
              </button>
              {historyOpen ? (
                <div className="history-popover" role="region" aria-label="Previous messages">
                  {historyMessages.map((m) => (
                    <div
                      key={m.id}
                      className={`history-row history-row--${m.role}`}
                    >
                      <span className="history-role">{m.role}</span>
                      <div className="history-text">
                        {m.role === 'assistant' ? (
                          <MarkdownMessage content={m.text} className="markdown-body--compact" />
                        ) : (
                          m.text
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              ) : null}
            </div>
          ) : null}

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
      </footer>
    </div>
  )
}
