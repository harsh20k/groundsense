import type { AgentResponse } from './types'

function resolveInvokeUrl(): string {
  const raw = import.meta.env.VITE_API_BASE_URL?.trim()
  if (!raw) {
    throw new Error(
      'Set VITE_API_BASE_URL to your API Gateway invoke URL (terraform output api_invoke_url)',
    )
  }
  const base = raw.replace(/\/$/, '')
  return base.endsWith('/invoke') ? base : `${base}/invoke`
}

export async function invokeFormatter(
  query: string,
  sessionId: string | undefined,
): Promise<AgentResponse> {
  const url = resolveInvokeUrl()
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query,
      ...(sessionId ? { session_id: sessionId } : {}),
    }),
  })

  const data: unknown = await res.json().catch(() => ({}))

  if (!res.ok) {
    const err =
      typeof data === 'object' && data !== null && 'error' in data
        ? String((data as { error: unknown }).error)
        : res.statusText
    throw new Error(err || `Request failed (${res.status})`)
  }

  return data as AgentResponse
}
