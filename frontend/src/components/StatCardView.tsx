interface Props {
  title?: string
  data: Record<string, unknown>
}

function formatKey(k: string): string {
  return k.replace(/_/g, ' ')
}

export function StatCardView({ title, data }: Props) {
  const entries = Object.entries(data).filter(
    ([, v]) => v !== null && v !== undefined && v !== '',
  )

  if (!entries.length) {
    return (
      <div className="viz-panel">
        {title ? <h3 className="viz-title">{title}</h3> : null}
        <p className="viz-empty">No statistics returned.</p>
      </div>
    )
  }

  return (
    <div className="viz-panel">
      {title ? <h3 className="viz-title">{title}</h3> : null}
      <div className="stat-grid">
        {entries.map(([k, v]) => (
          <div key={k} className="stat-cell">
            <span className="stat-label">{formatKey(k)}</span>
            <span className="stat-value">{String(v)}</span>
          </div>
        ))}
      </div>
    </div>
  )
}
