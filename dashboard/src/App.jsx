import { useState, useEffect } from 'react'
import axios from 'axios'

const SERVICES = [
  { name: 'Example Service', url: 'http://localhost:8000' },
  // Add your team services here
]

function App() {
  const [statuses, setStatuses] = useState({})

  useEffect(() => {
    SERVICES.forEach(svc => {
      axios.get(`${svc.url}/health`)
        .then(res => setStatuses(prev => ({ ...prev, [svc.name]: res.data })))
        .catch(() => setStatuses(prev => ({ ...prev, [svc.name]: { status: 'unreachable' } })))
    })
  }, [])

  return (
    <div style={{ padding: '2rem', fontFamily: 'sans-serif' }}>
      <h1>Platform Dashboard</h1>
      <table style={{ borderCollapse: 'collapse', width: '100%', marginTop: '1rem' }}>
        <thead>
          <tr>
            <th style={{ textAlign: 'left', padding: '0.5rem', borderBottom: '1px solid #ccc' }}>Service</th>
            <th style={{ textAlign: 'left', padding: '0.5rem', borderBottom: '1px solid #ccc' }}>Status</th>
            <th style={{ textAlign: 'left', padding: '0.5rem', borderBottom: '1px solid #ccc' }}>Endpoint</th>
          </tr>
        </thead>
        <tbody>
          {SERVICES.map(svc => {
            const data = statuses[svc.name] || {}
            const healthy = data.status === 'healthy'
            return (
              <tr key={svc.name}>
                <td style={{ padding: '0.5rem' }}>{svc.name}</td>
                <td style={{ padding: '0.5rem', color: healthy ? 'green' : 'red' }}>
                  {data.status || 'checking...'}
                </td>
                <td style={{ padding: '0.5rem' }}>{data.endpoint || '—'}</td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}

export default App
