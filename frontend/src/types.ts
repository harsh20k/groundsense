export type VizType =
  | 'earthquake_map'
  | 'line_chart'
  | 'stat_card'
  | 'location_map'
  | 'weather_card'
  | 'document_excerpt'
  | 'none'

export interface Visualization {
  type: VizType
  title?: string
  data?: unknown
}

export interface AgentResponse {
  message: string
  session_id: string
  visualization: Visualization
}

export interface EarthquakePoint {
  latitude: number
  longitude: number
  magnitude?: number
  place?: string
  time?: string
  depth_km?: number
  earthquake_id?: string
}

export interface LineChartRow {
  month: string
  event_count?: number
  avg_magnitude?: number
  max_magnitude?: number
}

export interface ContextExcerpt {
  content: string
  relevance_score?: number
  source?: string
}

export interface LocationMapData {
  latitude: number
  longitude: number
  name?: string
  nearest_city?: string
  nearby_cities?: string[]
  context_excerpts?: ContextExcerpt[]
}

export interface DocRow {
  content: string
  source?: string
  score?: number
}
