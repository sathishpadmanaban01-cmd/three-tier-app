import { useEffect, useState } from 'react'

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

export default function App() {
  const [health, setHealth] = useState(null)
  const [products, setProducts] = useState([])
  const [order, setOrder] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    fetch(`${API_BASE}/health`)
      .then((r) => r.json())
      .then(setHealth)
      .catch((e) => setError(String(e)))
  }, [])

  async function loadProducts() {
    setError('')
    const res = await fetch(`${API_BASE}/products`)
    if (!res.ok) {
      setError(`Products call failed: ${res.status}`)
      return
    }
    setProducts(await res.json())
  }

  async function createOrder(productId) {
    setError('')
    const res = await fetch(`${API_BASE}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        customer_name: 'Demo User',
        product_id: productId,
        quantity: 1
      })
    })
    if (!res.ok) {
      setError(`Order create failed: ${res.status}`)
      return
    }
    setOrder(await res.json())
  }

  return (
    <div className="container">
      <h1>Three-Tier Demo</h1>
      <p>React frontend calling FastAPI on EKS.</p>

      <section>
        <h2>Health</h2>
        <pre>{JSON.stringify(health, null, 2)}</pre>
      </section>

      <section>
        <h2>Products</h2>
        <button onClick={loadProducts}>Load products</button>
        <div className="grid">
          {products.map((p) => (
            <div className="card" key={p.id}>
              <h3>{p.name}</h3>
              <p>{p.description}</p>
              <p>£{p.price}</p>
              <button onClick={() => createOrder(p.id)}>Create order</button>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2>Last order</h2>
        <pre>{JSON.stringify(order, null, 2)}</pre>
      </section>

      {error && (
        <section>
          <h2>Error</h2>
          <pre>{error}</pre>
        </section>
      )}
    </div>
  )
}
