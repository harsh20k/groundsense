import { MapContainer, TileLayer, CircleMarker, Popup } from 'react-leaflet'
import type { LocationMapData } from '../types'

interface Props {
  title?: string
  data: LocationMapData
}

export function LocationMapView({ title, data }: Props) {
  const { latitude, longitude } = data
  if (
    typeof latitude !== 'number' ||
    typeof longitude !== 'number' ||
    Number.isNaN(latitude) ||
    Number.isNaN(longitude)
  ) {
    return (
      <div className="viz-panel">
        {title ? <h3 className="viz-title">{title}</h3> : null}
        <p className="viz-empty">No coordinates for this location.</p>
      </div>
    )
  }

  const excerpts = data.context_excerpts ?? []

  return (
    <div className="viz-panel">
      {title ? <h3 className="viz-title">{title}</h3> : null}
      <MapContainer
        center={[latitude, longitude]}
        zoom={7}
        className="leaflet-wrap leaflet-wrap--sm"
        scrollWheelZoom
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <CircleMarker
          center={[latitude, longitude]}
          radius={12}
          pathOptions={{
            color: '#2563eb',
            fillColor: '#3b82f6',
            fillOpacity: 0.5,
            weight: 2,
          }}
        >
          <Popup>
            {data.name || data.nearest_city || 'Location'}
            {data.nearest_city && data.name !== data.nearest_city ? (
              <>
                <br />
                <span className="text-muted">{data.nearest_city}</span>
              </>
            ) : null}
          </Popup>
        </CircleMarker>
      </MapContainer>
      {(data.nearby_cities?.length ?? 0) > 0 ? (
        <p className="viz-meta">
          Nearby: {(data.nearby_cities ?? []).join(', ')}
        </p>
      ) : null}
      {excerpts.length > 0 ? (
        <ul className="excerpt-list">
          {excerpts.slice(0, 5).map((ex, i) => (
            <li key={i}>
              <span className="excerpt-src">{ex.source ?? 'Source'}</span>
              <p>{ex.content}</p>
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  )
}
