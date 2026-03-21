export interface PresetQuery {
  id: string
  label: string
  query: string
}

export const PRESET_QUERIES: PresetQuery[] = [
  {
    id: 'earthquake_map',
    label: 'Map',
    query:
      'Show recent magnitude 4 and above earthquakes in western Canada on a map for the last 7 days.',
  },
  {
    id: 'line_chart',
    label: 'Trends',
    query: 'Plot monthly earthquake event counts for the last 12 months as a line chart.',
  },
  {
    id: 'stat_card',
    label: 'Stats',
    query: 'Give me summary statistics for recent seismic activity in Canada.',
  },
  {
    id: 'location_map',
    label: 'Location',
    query: 'Where was the most recent significant earthquake near Vancouver? Show it on a map.',
  },
  {
    id: 'weather_card',
    label: 'Weather',
    query: 'What is the current weather at the epicenter of the latest notable earthquake?',
  },
  {
    id: 'document_excerpt',
    label: 'Sources',
    query: 'What do our knowledge sources say about earthquake preparedness in BC?',
  },
]
