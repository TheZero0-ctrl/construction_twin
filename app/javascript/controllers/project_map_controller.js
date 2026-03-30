import { Controller } from "@hotwired/stimulus"
import {
  Viewer,
  ImageryLayer,
  OpenStreetMapImageryProvider,
  GeoJsonDataSource,
  Cesium3DTileset,
  Cesium3DTileStyle,
  Color,
  JulianDate,
  HeadingPitchRange,
  Math as CesiumMath,
  Cartographic,
  Cartesian3
} from "cesium"

window.CESIUM_BASE_URL = "/cesium"

export default class extends Controller {
  static targets = ["container", "layersPanel", "status"]
  static values = {
    layersUrl: String,
    fallbackBuildingsUrl: String
  }

  static DEFAULT_BUILDING_HEIGHT = 28
  static MIN_TILESET_RANGE_METERS = 1500
  static MAX_TILESET_RANGE_METERS = 25000

  connect() {
    this.layerObjects = new Map()
    this.layersById = new Map()
    this.debugTiles = new URLSearchParams(window.location.search).get("tiles_debug") === "1"

    if (this.hasContainerTarget) {
      this.baseImageryProvider = new OpenStreetMapImageryProvider({
        url: "https://tile.openstreetmap.org/",
        maximumLevel: 19
      })

      this.viewer = new Viewer(this.containerTarget, {
        animation: false,
        baseLayerPicker: false,
        baseLayer: new ImageryLayer(this.baseImageryProvider),
        fullscreenButton: false,
        geocoder: false,
        homeButton: true,
        infoBox: true,
        navigationHelpButton: false,
        sceneModePicker: false,
        selectionIndicator: true,
        timeline: false
      })

      this.baseImageryProvider.errorEvent.addEventListener(() => {
        this.setStatus("Basemap imagery failed to load. Tiles are still being rendered.")
      })
    }

    this.loadLayers()
  }

  disconnect() {
    this.abortLayersRequest()

    if (!this.viewer) return

    this.viewer.destroy()
    this.viewer = null
    this.layerObjects.clear()
    this.layersById.clear()
  }

  async loadLayers() {
    if (!this.hasLayersUrlValue) return

    this.abortLayersRequest()
    const request = new AbortController()
    this.layersRequest = request

    this.setStatus("Loading layers...")

    try {
      const response = await fetch(this.layersUrlValue, {
        headers: { Accept: "application/json" },
        signal: request.signal
      })

      if (!response.ok) {
        this.setStatus("Could not load map layers.")
        return
      }

      const payload = await response.json()
      const layers = payload.layers || []
      this.renderLayerControls(layers)

      const readyCount = layers.filter((layer) => layer.status === "ready").length
      this.setStatus(`Loaded ${layers.length} layer${layers.length === 1 ? "" : "s"}. ${readyCount} ready.`)
    } catch (error) {
      if (error.name === "AbortError") return

      this.setStatus("Could not load map layers.")
    } finally {
      if (this.layersRequest === request) {
        this.layersRequest = null
      }
    }
  }

  renderLayerControls(layers) {
    if (!this.hasLayersPanelTarget) return

    this.layersPanelTarget.innerHTML = ""
    this.layersById.clear()

    if (layers.length === 0) {
      this.layersPanelTarget.innerHTML = "<p class='text-sm text-stone-500'>No layers available yet.</p>"
      return
    }

    layers.forEach((layer) => {
      this.layersById.set(layer.id, layer)

      const row = document.createElement("label")
      row.className = "flex items-center justify-between gap-3 rounded-2xl border border-stone-200 bg-stone-50 px-3 py-2 text-sm text-stone-700"

      const text = document.createElement("div")
      text.className = "min-w-0"
      text.innerHTML = `
        <p class="truncate font-medium text-stone-900">${layer.name}</p>
        <p class="truncate text-xs text-stone-500">${layer.layer_type} · ${layer.status}</p>
      `

      const checkbox = document.createElement("input")
      checkbox.type = "checkbox"
      checkbox.className = "h-4 w-4 rounded border-stone-300 text-stone-900"
      checkbox.checked = Boolean(layer.visible)
      checkbox.disabled = !["ready", "failed", "pending", "processing"].includes(layer.status)
      checkbox.addEventListener("change", () => this.toggleLayer(layer.id, checkbox))

      row.append(text, checkbox)
      this.layersPanelTarget.appendChild(row)

      if (checkbox.checked) {
        this.showLayer(layer).catch(() => {
          this.setStatus(`Could not load layer '${layer.name}'.`)
        })
      }
    })
  }

  async toggleLayer(layerId, checkbox) {
    const layer = this.layersById.get(layerId)
    if (!layer) return

    const visible = checkbox.checked

    try {
      await this.persistVisibility(layerId, visible)
      layer.visible = visible
      if (visible) {
        await this.showLayer(layer)
      } else {
        this.hideLayer(layerId)
      }
    } catch (_error) {
      checkbox.checked = !visible
      this.setStatus("Could not update layer visibility.")
    }
  }

  async showLayer(layer) {
    if (!this.viewer) return
    if (this.layerObjects.has(layer.id)) return

    const activeTileset = (layer.artifacts || []).find((artifact) => artifact.active && artifact.status === "ready" && artifact.format === "tiles_3d" && artifact.url)
    if (activeTileset) {
      await this.showTilesetLayer(layer, activeTileset.url)
      return
    }

    if (layer.layer_type === "buildings" && this.hasFallbackBuildingsUrlValue) {
      await this.showGeojsonFallbackLayer(layer.id)
    }
  }

  async showTilesetLayer(layer, tilesetUrl) {
    const layerId = layer.id
    const tileset = await Cesium3DTileset.fromUrl(tilesetUrl, {
      maximumScreenSpaceError: 2,
      dynamicScreenSpaceError: false
    })

    tileset.maximumScreenSpaceError = 2
    tileset.dynamicScreenSpaceError = false
    tileset.backFaceCulling = false
    tileset.style = new Cesium3DTileStyle({
      color: "color('#d6b58a', 0.98)",
      show: "true"
    })

    let hasVisibleTiles = false
    tileset.tileFailed.addEventListener((error) => {
      this.setStatus(`Tile failed: ${error?.message || "Unknown tile error"}`)
    })

    tileset.tileVisible.addEventListener(() => {
      if (hasVisibleTiles) return
      hasVisibleTiles = true
      this.setStatus("3D buildings rendered.")
    })

    tileset.loadProgress.addEventListener((pendingRequests, processingTiles) => {
      if (pendingRequests === 0 && processingTiles === 0) return
      this.setStatus(`Loading 3D tiles... requests: ${pendingRequests}, processing: ${processingTiles}`)
    })

    if (this.debugTiles) {
      tileset.debugColorizeTiles = true
      tileset.debugShowBoundingVolume = true
    }

    this.viewer.scene.primitives.add(tileset)
    this.layerObjects.set(layerId, { type: "tileset", object: tileset })

    const radius = tileset.boundingSphere?.radius || 0
    const range = CesiumMath.clamp(
      radius * 0.15,
      this.constructor.MIN_TILESET_RANGE_METERS,
      this.constructor.MAX_TILESET_RANGE_METERS
    )

    const offset = new HeadingPitchRange(0, CesiumMath.toRadians(-40), range)
    const sphere = tileset.boundingSphere
    if (sphere?.center) {
      const centerCartographic = Cartographic.fromCartesian(sphere.center)
      const destinationHeight = radius > 100_000 ? 2500 : 1200

      this.viewer.camera.flyTo({
        destination: Cartesian3.fromRadians(
          centerCartographic.longitude,
          centerCartographic.latitude,
          destinationHeight
        ),
        duration: 1.8,
        orientation: {
          heading: 0,
          pitch: CesiumMath.toRadians(-70),
          roll: 0
        }
      })
    } else {
      this.viewer.camera.flyToBoundingSphere(tileset.boundingSphere, {
        duration: 1.8,
        offset
      })
    }

    if (radius > 100_000) {
      this.setStatus("Layer loaded. Dataset covers a large area; zoom in to inspect buildings.")
    }

    setTimeout(async () => {
      if (hasVisibleTiles || !this.layerObjects.has(layerId)) return
      if (layer.layer_type !== "buildings" || !this.hasFallbackBuildingsUrlValue) return

      this.setStatus("3D tiles loaded but not visible. Showing GeoJSON fallback.")
      this.hideLayer(layerId)
      await this.showGeojsonFallbackLayer(layerId)
    }, 5000)
  }

  async showGeojsonFallbackLayer(layerId) {
    const response = await fetch(this.fallbackBuildingsUrlValue, { headers: { Accept: "application/json" } })
    if (!response.ok) return

    const payload = await response.json()
    const geoJson = { type: "FeatureCollection", features: payload.features || [] }

    const dataSource = await GeoJsonDataSource.load(geoJson, {
      clampToGround: false,
      stroke: Color.fromCssColorString("#1c1917"),
      strokeWidth: 1,
      fill: Color.fromCssColorString("#57534e").withAlpha(0.75)
    })

    dataSource.entities.values.forEach((entity) => {
      if (!entity.polygon) return
      entity.polygon.extrudedHeight = this.buildingHeightFor(entity)
      entity.polygon.height = 0
      entity.polygon.material = Color.fromCssColorString("#d6b58a").withAlpha(0.95)
      entity.polygon.outline = true
      entity.polygon.outlineColor = Color.fromCssColorString("#6b4f34")
    })

    this.viewer.dataSources.add(dataSource)
    this.layerObjects.set(layerId, { type: "datasource", object: dataSource })

    if (dataSource.entities.values.length > 0) {
      await this.viewer.flyTo(dataSource)
    }
  }

  hideLayer(layerId) {
    if (!this.viewer) return

    const item = this.layerObjects.get(layerId)
    if (!item) return

    if (item.type === "tileset") {
      this.viewer.scene.primitives.remove(item.object)
    }

    if (item.type === "datasource") {
      this.viewer.dataSources.remove(item.object)
    }

    this.layerObjects.delete(layerId)
  }

  async persistVisibility(layerId, visible) {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    const response = await fetch(`${this.layersUrlValue}/${layerId}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        Accept: "application/json"
      },
      body: JSON.stringify({ layer: { visible } })
    })

    if (!response.ok) {
      throw new Error("Visibility update failed")
    }
  }

  buildingHeightFor(entity) {
    const rawHeight = entity.properties?.height?.getValue(JulianDate.now())
    const numericHeight = Number(rawHeight)

    return Number.isFinite(numericHeight) && numericHeight > 0 ? numericHeight : this.constructor.DEFAULT_BUILDING_HEIGHT
  }

  setStatus(message) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
  }

  abortLayersRequest() {
    if (!this.layersRequest) return

    this.layersRequest.abort()
    this.layersRequest = null
  }
}
