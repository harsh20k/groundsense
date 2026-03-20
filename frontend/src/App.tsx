import { useCallback, useRef, useState } from 'react'
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
  const [lastViz, setLastViz] = useState<Visualization | null>(null)
  const listRef = useRef<HTMLDivElement>(null)

  const scrollToBottom = useCallback(() => {
    requestAnimationFrame(() => {
      listRef.current?.scrollTo({
        top: listRef.current.scrollHeight,
        behavior: 'smooth',
      })
    })
  }, [])

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
      setLastViz(res.visualization)
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

  const activeViz =
    lastViz ??
    [...messages].reverse().find((m) => m.visualization)?.visualization ?? {
      type: 'none' as const,
    }

  return (
    <div className="app">
      <aside className="sidebar">
        <div className="brand">
          <h1>GroundSense</h1>
          <p>Earthquake Q&amp;A (prototype)</p>
        </div>
        <div className="messages" ref={listRef}>
          {messages.length === 0 ? (
            <p className="viz-empty" style={{ padding: '0 0.25rem' }}>
              Ask about recent quakes, trends, or locations. Session is kept for
              follow-up questions.
            </p>
          ) : null}
          {messages.map((m) => (
            <div
              key={m.id}
              className={`msg ${m.role === 'user' ? 'msg-user' : ''} ${m.role === 'assistant' ? 'msg-assistant' : ''} ${m.role === 'error' ? 'msg-error' : ''}`}
            >
              {m.text}
              {m.role === 'assistant' && m.visualization ? (
                <span className="msg-meta">viz: {m.visualization.type}</span>
              ) : null}
            </div>
          ))}
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
          />
          <button type="button" onClick={() => void send()} disabled={loading || !input.trim()}>
            {loading ? 'Thinking…' : 'Send'}
          </button>
        </div>
      </aside>
      <main className="main">
        {loading ? <p className="loading-banner">Calling agent…</p> : null}
        <VisualizationRouter visualization={activeViz} />
      </main>
    </div>
  )
}
