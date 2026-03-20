import type { DocRow } from '../types'

interface Props {
  title?: string
  rows: DocRow[]
}

export function DocumentExcerptView({ title, rows }: Props) {
  if (!rows.length) {
    return (
      <div className="viz-panel">
        {title ? <h3 className="viz-title">{title}</h3> : null}
        <p className="viz-empty">No document excerpts.</p>
      </div>
    )
  }

  return (
    <div className="viz-panel">
      {title ? <h3 className="viz-title">{title}</h3> : null}
      <ul className="doc-list">
        {rows.map((row, i) => (
          <li key={i} className="doc-card">
            <header>
              <span className="doc-source">{row.source ?? 'Document'}</span>
              {row.score != null ? (
                <span className="doc-score">{(row.score * 100).toFixed(0)}% match</span>
              ) : null}
            </header>
            <p>{row.content}</p>
          </li>
        ))}
      </ul>
    </div>
  )
}
