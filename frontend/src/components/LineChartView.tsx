import { Line } from 'react-chartjs-2'
import type { LineChartRow } from '../types'

const lineColor = '#b85c3a'
const lineFill = 'rgba(184, 92, 58, 0.12)'
const tickColor = '#6b6256'
const gridColor = 'rgba(107, 98, 86, 0.12)'

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
                borderColor: lineColor,
                backgroundColor: lineFill,
                fill: true,
                tension: 0.25,
              },
            ],
          }}
          options={{
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: { display: true, labels: { color: tickColor } },
            },
            scales: {
              x: {
                ticks: { color: tickColor, maxRotation: 45 },
                grid: { color: gridColor },
              },
              y: {
                ticks: { color: tickColor },
                grid: { color: gridColor },
                beginAtZero: true,
              },
            },
          }}
        />
      </div>
    </div>
  )
}
