import { MapContainer, TileLayer, CircleMarker, Popup } from 'react-leaflet'
import type { EarthquakePoint } from '../types'

function magnitudeRadius(m: number | undefined): number {
  if (m == null || Number.isNaN(m)) return 6
  return Math.min(22, 4 + m * 3)
}

function magnitudeColor(m: number | undefined): string {
  if (m == null || Number.isNaN(m)) return '#64748b'
  if (m >= 5) return '#dc2626'
  if (m >= 4) return '#ea580c'
  if (m >= 3) return '#ca8a04'
  return '#16a34a'
}

interface Props {
  title?: string
  data: EarthquakePoint[]
}

export function EarthquakeMapView({ title, data }: Props) {
  const valid = data.filter(
    (p) =>
      typeof p.latitude === 'number' &&
      typeof p.longitude === 'number' &&
      !Number.isNaN(p.latitude) &&
      !Number.isNaN(p.longitude),
  )

  const center: [number, number] =
    valid.length > 0
      ? [
          valid.reduce((s, p) => s + p.latitude, 0) / valid.length,
          valid.reduce((s, p) => s + p.longitude, 0) / valid.length,
        ]
      : [56.13, -106.34]

  return (
    <div className="viz-panel">
      {title ? <h3 className="viz-title">{title}</h3> : null}
      {valid.length === 0 ? (
        <p className="viz-empty">No mappable events in this response.</p>
      ) : (
        <MapContainer
          center={center}
          zoom={valid.length === 1 ? 6 : 4}
          className="leaflet-wrap"
          scrollWheelZoom
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          {valid.map((p, i) => (
            <CircleMarker
              key={`${p.earthquake_id ?? i}-${p.time ?? ''}`}
              center={[p.latitude, p.longitude]}
              radius={magnitudeRadius(p.magnitude)}
              pathOptions={{
                color: magnitudeColor(p.magnitude),
                fillColor: magnitudeColor(p.magnitude),
                fillOpacity: 0.55,
                weight: 1,
              }}
            >
              <Popup>
                <strong>M {p.magnitude ?? '?'}</strong>
                <br />
                {p.place ?? 'Unknown'}
                <br />
                {p.time ?? ''}
              </Popup>
            </CircleMarker>
          ))}
        </MapContainer>
      )}
    </div>
  )
}
