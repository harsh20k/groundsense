import { Line } from 'react-chartjs-2'
import type { LineChartRow } from '../types'

interface Props {
  title?: string
  rows: LineChartRow[]
}

export function LineChartView({ title, rows }: Props) {
  if (!rows.length) {
    return (
      <div className="viz-panel">
        {title ? <h3 className="viz-title">{title}</h3> : null}
        <p className="viz-empty">No time series data.</p>
      </div>
    )
  }

  const labels = rows.map((r) => r.month)
  const counts = rows.map((r) => r.event_count ?? 0)

  return (
    <div className="viz-panel">
      {title ? <h3 className="viz-title">{title}</h3> : null}
      <div className="chart-wrap">
        <Line
          data={{
            labels,
            datasets: [
              {
                label: 'Event count',
                data: counts,
                borderColor: '#38bdf8',
                backgroundColor: 'rgba(56, 189, 248, 0.15)',
                fill: true,
                tension: 0.25,
              },
            ],
          }}
          options={{
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: { display: true, labels: { color: '#cbd5e1' } },
            },
            scales: {
              x: {
                ticks: { color: '#94a3b8', maxRotation: 45 },
                grid: { color: 'rgba(148, 163, 184, 0.15)' },
              },
              y: {
                ticks: { color: '#94a3b8' },
                grid: { color: 'rgba(148, 163, 184, 0.15)' },
                beginAtZero: true,
              },
            },
          }}
        />
      </div>
    </div>
  )
}
