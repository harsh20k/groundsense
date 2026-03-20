interface Props {
  title?: string
  data: Record<string, unknown>
}

function num(v: unknown): number | undefined {
  return typeof v === 'number' && !Number.isNaN(v) ? v : undefined
}

function str(v: unknown): string | undefined {
  return typeof v === 'string' ? v : undefined
}

export function WeatherCardView({ title, data }: Props) {
  const rows: { label: string; value: string }[] = [
    {
      label: 'Temperature',
      value: num(data.temperature) != null ? `${num(data.temperature)} °C` : '—',
    },
    { label: 'Wind', value: num(data.wind_speed) != null ? `${num(data.wind_speed)} km/h` : '—' },
    {
      label: 'Precipitation',
      value: num(data.precipitation) != null ? `${num(data.precipitation)} mm` : '—',
    },
    { label: 'Conditions', value: str(data.description) || '—' },
    { label: 'Seismic noise risk', value: str(data.noise_risk) || '—' },
  ]

  return (
    <div className="viz-panel">
      {title ? <h3 className="viz-title">{title}</h3> : null}
      <div className="weather-grid">
        {rows.map((r) => (
          <div key={r.label} className="weather-row">
            <span>{r.label}</span>
            <strong>{r.value}</strong>
          </div>
        ))}
      </div>
    </div>
  )
}
