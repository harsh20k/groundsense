import type { LocationMapData, Visualization } from '../types'
import { EarthquakeMapView } from './EarthquakeMapView'
import { LineChartView } from './LineChartView'
import { LocationMapView } from './LocationMapView'
import { StatCardView } from './StatCardView'
import { WeatherCardView } from './WeatherCardView'
import { DocumentExcerptView } from './DocumentExcerptView'

interface Props {
  visualization: Visualization
}

export function VisualizationRouter({ visualization }: Props) {
  const { type, title, data } = visualization

  switch (type) {
    case 'earthquake_map':
      return (
        <EarthquakeMapView
          title={title}
          data={Array.isArray(data) ? data : []}
        />
      )
    case 'line_chart':
      return (
        <LineChartView title={title} rows={Array.isArray(data) ? data : []} />
      )
    case 'stat_card':
      return (
        <StatCardView
          title={title}
          data={data && typeof data === 'object' && !Array.isArray(data) ? (data as Record<string, unknown>) : {}}
        />
      )
    case 'location_map': {
      const loc =
        data && typeof data === 'object' && !Array.isArray(data)
          ? (data as LocationMapData)
          : ({} as LocationMapData)
      return <LocationMapView title={title} data={loc} />
    }
    case 'weather_card':
      return (
        <WeatherCardView
          title={title}
          data={
            data && typeof data === 'object' && !Array.isArray(data)
              ? (data as Record<string, unknown>)
              : {}
          }
        />
      )
    case 'document_excerpt':
      return (
        <DocumentExcerptView
          title={title}
          rows={Array.isArray(data) ? data : []}
        />
      )
    case 'none':
    default:
      return (
        <div className="viz-panel">
          <p className="viz-empty">No visualization for this answer.</p>
        </div>
      )
  }
}
