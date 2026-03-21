import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { invokeFormatter } from './api'
import type { Visualization } from './types'
import { VisualizationRouter } from './components/VisualizationRouter'
import './App.css'

type ChatRole = 'user' | 'assistant' | 'error'

interface ChatMessage {
  id: string
  role: ChatRole
  text: string
  visualization?: Visualization
}

const emptyViz: Visualization = { type: 'none' }

let idCounter = 0
function nextId(): string {
  idCounter += 1
  return `m-${idCounter}`
}

export default function App() {
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [input, setInput] = useState('')
  const [sessionId, setSessionId] = useState<string | undefined>(undefined)
  const [loading, setLoading] = useState(false)
  const listRef = useRef<HTMLDivElement>(null)
  const vizHistRef = useRef<HTMLDivElement>(null)

  const { latestViz, vizHistory } = useMemo(() => {
    const withViz = messages.filter(
      (m) =>
        m.role === 'assistant' &&
        m.visualization &&
        m.visualization.type !== 'none',
    )
    const latestViz =
      withViz.length > 0 ? withViz[withViz.length - 1].visualization! : emptyViz
    const vizHistory = withViz.slice(0, -1)
    return { latestViz, vizHistory }
  }, [messages])

  const scrollToBottom = useCallback(() => {
    requestAnimationFrame(() => {
      listRef.current?.scrollTo({
        top: listRef.current.scrollHeight,
        behavior: 'smooth',
      })
    })
  }, [])

  useEffect(() => {
    if (vizHistory.length === 0) return
    requestAnimationFrame(() => {
      const el = vizHistRef.current
      if (!el) return
      el.scrollTo({ top: el.scrollHeight, behavior: 'smooth' })
    })
  }, [vizHistory.length])

  const send = useCallback(async () => {
    const query = input.trim()
    if (!query || loading) return

    setInput('')
    setMessages((prev) => [...prev, { id: nextId(), role: 'user', text: query }])
    setLoading(true)
    scrollToBottom()

    try {
      const res = await invokeFormatter(query, sessionId)
      setSessionId(res.session_id)
      setMessages((prev) => [
        ...prev,
        {
          id: nextId(),
          role: 'assistant',
          text: res.message || '(No text in response)',
          visualization: res.visualization,
        },
      ])
    } catch (e) {
      const text = e instanceof Error ? e.message : 'Request failed'
      setMessages((prev) => [...prev, { id: nextId(), role: 'error', text }])
    } finally {
      setLoading(false)
      scrollToBottom()
    }
  }, [input, loading, sessionId, scrollToBottom])

  const onKeyDown = (ev: React.KeyboardEvent) => {
    if (ev.key === 'Enter' && !ev.shiftKey) {
      ev.preventDefault()
      void send()
    }
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
        <aside className="col col-viz-history">
          <h2 className="col-heading">Visualization history</h2>
          <div className="viz-history-scroll" ref={vizHistRef}>
            {vizHistory.length === 0 ? (
              <p className="viz-empty col-empty">Past charts and maps appear here.</p>
            ) : (
              vizHistory.map((m) => (
                <div key={m.id} className="viz-history-item">
                  <VisualizationRouter visualization={m.visualization!} />
                </div>
              ))
            )}
          </div>
        </aside>

        <section className="col col-center" aria-busy={loading}>
          <div className="center-inner">
            <div className="center-viz">
              <VisualizationRouter visualization={latestViz} />
            </div>
            <div className="composer">
              {sessionId ? (
                <p className="session-hint" title={sessionId}>
                  Session: {sessionId.slice(0, 28)}
                  {sessionId.length > 28 ? '…' : ''}
                </p>
              ) : null}
              <textarea
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={onKeyDown}
                placeholder="e.g. M4+ earthquakes near Vancouver in the last 7 days"
                disabled={loading}
                aria-label="Question"
                rows={3}
              />
              <div className="composer-actions">
                {loading ? (
                  <span className="loading-inline" role="status" aria-live="polite">
                    <span className="spinner spinner--sm" aria-hidden="true" />
                    <span className="loading-inline-label">Thinking…</span>
                  </span>
                ) : (
                  <span className="composer-actions-spacer" />
                )}
                <button
                  type="button"
                  onClick={() => void send()}
                  disabled={loading || !input.trim()}
                >
                  Send
                </button>
              </div>
            </div>
          </div>
        </section>

        <aside className="col col-chat" aria-busy={loading}>
          <h2 className="col-heading">Chat</h2>
          <div className="chat-stack">
            <div className="messages" ref={listRef}>
              {messages.length === 0 ? (
                <p className="viz-empty chat-empty">
                  Ask about recent quakes, trends, or locations. Session is kept for follow-up
                  questions.
                </p>
              ) : null}
              {messages.map((m) => (
                <div
                  key={m.id}
                  className={`msg ${m.role === 'user' ? 'msg-user' : ''} ${m.role === 'assistant' ? 'msg-assistant' : ''} ${m.role === 'error' ? 'msg-error' : ''}`}
                >
                  {m.text}
                </div>
              ))}
            </div>
            {loading ? (
              <div className="loading-strip" role="status" aria-live="polite">
                <span className="spinner" aria-hidden="true" />
                <span className="loading-strip-label">Calling agent…</span>
              </div>
            ) : null}
          </div>
        </aside>
      </div>
    </div>
  )
}
