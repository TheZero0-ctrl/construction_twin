import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "buildingsToggle", "status"]
  static values = {
    buildingsUrl: String
  }

  static DEFAULT_BUILDING_HEIGHT = 12

  connect() {
    if (!this.hasContainerTarget || !window.Cesium) return

    const Cesium = window.Cesium

    this.viewer = new Cesium.Viewer(this.containerTarget, {
      animation: false,
      baseLayerPicker: false,
      fullscreenButton: false,
      geocoder: false,
      homeButton: true,
      imageryProvider: new Cesium.OpenStreetMapImageryProvider({
        url: "https://tile.openstreetmap.org/"
      }),
      infoBox: true,
      navigationHelpButton: false,
      sceneModePicker: false,
      selectionIndicator: true,
      timeline: false
    })

    this.loadBuildings()
  }

  disconnect() {
    this.abortBuildingsRequest()

    if (!this.viewer) return

    this.viewer.destroy()
    this.viewer = null
    this.buildingsDataSource = null
  }

  async loadBuildings() {
    if (!this.hasBuildingsUrlValue) return

    this.abortBuildingsRequest()
    const request = new AbortController()
    this.buildingsRequest = request

    this.setStatus("Loading buildings...")

    try {
      const response = await fetch(this.buildingsUrlValue, {
        headers: { Accept: "application/json" },
        signal: request.signal
      })
      if (!response.ok) {
        this.setStatus("Could not load building data.")
        return
      }

      const payload = await response.json()
      const Cesium = window.Cesium

      const geoJson = {
        type: "FeatureCollection",
        features: payload.features || []
      }

      this.buildingsDataSource = await Cesium.GeoJsonDataSource.load(geoJson, {
        clampToGround: false,
        stroke: Cesium.Color.fromCssColorString("#1c1917"),
        strokeWidth: 1,
        fill: Cesium.Color.fromCssColorString("#57534e").withAlpha(0.75)
      })

      this.viewer.dataSources.add(this.buildingsDataSource)
      this.applyBuildingStyles()
      this.syncBuildingsVisibility()

      if (this.buildingsDataSource.entities.values.length > 0) {
        this.viewer.flyTo(this.buildingsDataSource)
      }

      this.setStatus(this.statusMessage(payload.meta))
    } catch (error) {
      if (error.name === "AbortError") return

      this.setStatus("Could not load building data.")
    } finally {
      if (this.buildingsRequest === request) {
        this.buildingsRequest = null
      }
    }
  }

  applyBuildingStyles() {
    if (!this.buildingsDataSource) return

    const Cesium = window.Cesium
    const entities = this.buildingsDataSource.entities.values

    entities.forEach((entity) => {
      if (!entity.polygon) return

      entity.polygon.extrudedHeight = this.buildingHeightFor(entity)
      entity.polygon.height = 0
      entity.polygon.material = Cesium.Color.fromCssColorString("#78716c").withAlpha(0.85)
      entity.polygon.outline = true
      entity.polygon.outlineColor = Cesium.Color.fromCssColorString("#1c1917")
    })
  }

  toggleBuildings() {
    if (!this.buildingsDataSource || !this.hasBuildingsToggleTarget) return

    this.syncBuildingsVisibility()
  }

  syncBuildingsVisibility() {
    if (!this.buildingsDataSource || !this.hasBuildingsToggleTarget) return

    this.buildingsDataSource.show = this.buildingsToggleTarget.checked
  }

  buildingHeightFor(entity) {
    const Cesium = window.Cesium
    const rawHeight = entity.properties?.height?.getValue(Cesium.JulianDate.now())
    const numericHeight = Number(rawHeight)

    return Number.isFinite(numericHeight) && numericHeight > 0 ? numericHeight : this.constructor.DEFAULT_BUILDING_HEIGHT
  }

  setStatus(message) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
  }

  statusMessage(meta) {
    if (!meta) return ""

    const returnedCount = this.numberValue(meta.returned_count)
    const totalCount = this.numberValue(meta.total_count)

    if (meta.truncated) {
      return `Showing ${returnedCount.toLocaleString()} of ${totalCount.toLocaleString()} buildings for responsiveness.`
    }

    return `Loaded ${returnedCount.toLocaleString()} buildings.`
  }

  numberValue(value) {
    const number = Number(value)

    return Number.isFinite(number) ? number : 0
  }

  abortBuildingsRequest() {
    if (!this.buildingsRequest) return

    this.buildingsRequest.abort()
    this.buildingsRequest = null
  }
}
