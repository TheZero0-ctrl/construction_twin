import { Controller } from "@hotwired/stimulus"
import {
  Viewer,
  ImageryLayer,
  OpenStreetMapImageryProvider,
  GeoJsonDataSource,
  Cesium3DTileset,
  Cesium3DTileStyle,
  Cesium3DTileColorBlendMode,
  CustomShader,
  CustomShaderMode,
  LightingModel,
  ShadowMode,
  Cartesian2,
  Entity,
  Color,
  JulianDate,
  HeadingPitchRange,
  Math as CesiumMath,
  ScreenSpaceEventType
} from "cesium"

window.CESIUM_BASE_URL = "/cesium"

export default class extends Controller {
  static targets = ["container", "layersPanel", "status"]
  static values = {
    layersUrl: String
  }

  static DEFAULT_BUILDING_HEIGHT = 28
  static DEFAULT_TERRAIN_HEIGHT = 6
  static DEFAULT_ROAD_HEIGHT = 1
  static MIN_TILESET_RANGE_METERS = 1500
  static MAX_TILESET_RANGE_METERS = 25000

  connect() {
    this.layerObjects = new Map()
    this.layersById = new Map()
    // this.debugTiles = new URLSearchParams(window.location.search).get("tiles_debug") === "1"

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

      this.setupInfoBoxSelectionHandler()
    }

    this.loadLayers()
  }

  disconnect() {
    this.abortLayersRequest()

    if (!this.viewer) return

    this.viewer.screenSpaceEventHandler.removeInputAction(ScreenSpaceEventType.LEFT_CLICK)

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
        this.showLayer(layer).catch((error) => {
          this.setStatus(`Could not load layer '${layer.name}': ${error?.message || "Unknown error"}`)
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

    if (layer.fallback_geojson_url) {
      await this.showGeojsonFallbackLayer(layer)
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
    tileset.ocLayerId = layerId
    const tilesetStyle = this.tilesetStyleFor(layer.layer_type)
    if (tilesetStyle) {
      tileset.style = tilesetStyle
    }
    if (layer.layer_type === "buildings") {
      tileset.customShader = new CustomShader({
        mode: CustomShaderMode.MODIFY_MATERIAL,
        lightingModel: LightingModel.UNLIT
      })
      tileset.shadows = ShadowMode.DISABLED
      if (tileset.imageBasedLighting) {
        tileset.imageBasedLighting.imageBasedLightingFactor = new Cartesian2(0, 0)
      }
    }
    tileset.colorBlendMode = Cesium3DTileColorBlendMode.REPLACE
    tileset.colorBlendAmount = 1.0

    let hasVisibleTiles = false

    tileset.tileFailed.addEventListener((error) => {
      this.setStatus(`Tile failed: ${error?.message || "Unknown tile error"}`)
    })

    tileset.tileVisible.addEventListener((tile) => {
      if (layer.layer_type === "buildings") {
        this.applyBuildingFeatureColors(tile)
      }

      if (hasVisibleTiles) return

      hasVisibleTiles = true
      this.setStatus(`${layer.name || "Layer"} rendered.`)
    })

    // tileset.loadProgress.addEventListener((pendingRequests, processingTiles) => {
    //   if (pendingRequests === 0 && processingTiles === 0) return
    //   this.setStatus(`Loading 3D tiles... requests: ${pendingRequests}, processing: ${processingTiles}`)
    // })

    // if (this.debugTiles) {
    //   tileset.debugColorizeTiles = true
    //   tileset.debugShowBoundingVolume = true
    // }

    this.viewer.scene.primitives.add(tileset)
    this.layerObjects.set(layerId, { type: "tileset", object: tileset, layer })

    const radius = tileset.boundingSphere?.radius || 0
    const range = CesiumMath.clamp(
      radius * 0.15,
      this.constructor.MIN_TILESET_RANGE_METERS,
      this.constructor.MAX_TILESET_RANGE_METERS
    )

    const offset = new HeadingPitchRange(0, CesiumMath.toRadians(-40), range)
    const flySucceeded = await this.viewer.flyTo(tileset, {
      duration: 1.8,
      offset
    })

    if (!flySucceeded) {
      const sphere = tileset.boundingSphere
      if (sphere?.center && Number.isFinite(sphere.radius) && sphere.radius > 0) {
        this.viewer.camera.flyToBoundingSphere(sphere, {
          duration: 1.8,
          offset
        })
      }
    }

    if (radius > 100_000) {
      this.setStatus("Layer loaded. Dataset covers a large area; zoom in to inspect buildings.")
    }

    setTimeout(async () => {
      if (hasVisibleTiles || !this.layerObjects.has(layerId)) return
      if (!layer.fallback_geojson_url) return

      this.setStatus("3D tiles loaded but not visible. Showing GeoJSON fallback.")
      this.hideLayer(layerId)
      await this.showGeojsonFallbackLayer(layer)
    }, 5000)
  }

  async showGeojsonFallbackLayer(layer) {
    const response = await fetch(layer.fallback_geojson_url, { headers: { Accept: "application/json" } })
    if (!response.ok) return

    const payload = await response.json()
    const geoJson = { type: "FeatureCollection", features: payload.features || [] }

    const dataSource = await GeoJsonDataSource.load(geoJson, {
      clampToGround: false,
      ...this.geojsonStyleFor(layer.layer_type)
    })

    dataSource.entities.values.forEach((entity) => {
      if (!entity.polygon) return
      entity.polygon.extrudedHeight = this.featureHeightFor(entity, layer.layer_type)
      entity.polygon.height = 0
      entity.polygon.material = this.geojsonFillMaterialFor(layer.layer_type, entity)
      entity.polygon.outline = true
      entity.polygon.outlineColor = this.geojsonOutlineColorFor(layer.layer_type)
    })

    this.viewer.dataSources.add(dataSource)
    this.layerObjects.set(layer.id, { type: "datasource", object: dataSource, layer })

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

  featureHeightFor(entity, layerType) {
    const rawHeight = entity.properties?.height?.getValue(JulianDate.now())
    const numericHeight = Number(rawHeight)

    if (Number.isFinite(numericHeight) && numericHeight > 0) {
      return numericHeight
    }

    return this.defaultHeightForLayer(layerType)
  }

  defaultHeightForLayer(layerType) {
    if (layerType === "terrain") return this.constructor.DEFAULT_TERRAIN_HEIGHT
    if (layerType === "roads") return this.constructor.DEFAULT_ROAD_HEIGHT

    return this.constructor.DEFAULT_BUILDING_HEIGHT
  }

  tilesetStyleFor(layerType) {
    if (layerType === "buildings") {
      return null
    }

    const namedColor = this.namedTilesetColorFor(layerType)
    const unnamedColor = this.unnamedTilesetColorFor(layerType)

    return new Cesium3DTileStyle({
      color: {
        conditions: [
          ["${name} !== null && ${name} !== ''", namedColor],
          ["true", unnamedColor]
        ]
      },
      show: "true"
    })
  }

  applyBuildingFeatureColors(tile) {
    const content = tile?.content
    const featuresLength = content?.featuresLength
    if (!Number.isFinite(featuresLength) || featuresLength <= 0) return
    if (content.ocFeatureColorsApplied) return

    const namedColor = Color.fromCssColorString("#2f6f5e")
    const unnamedColor = Color.fromCssColorString("#c8c2b3")

    for (let index = 0; index < featuresLength; index += 1) {
      const feature = content.getFeature(index)
      if (!feature) continue

      const featureName = this.readFeatureName(feature)
      feature.color = this.hasMeaningfulName(featureName) ? namedColor : unnamedColor
    }

    content.ocFeatureColorsApplied = true
  }

  readFeatureName(feature) {
    if (!feature || typeof feature.getProperty !== "function") return null

    const candidates = [
      feature.getProperty("name"),
      feature.getProperty("Name"),
      feature.getProperty("NAME")
    ]

    for (const candidate of candidates) {
      if (candidate !== null && candidate !== undefined) {
        return candidate
      }
    }

    return null
  }

  hasMeaningfulName(value) {
    if (value === null || value === undefined) return false

    const normalized = String(value).trim().toLowerCase()
    if (normalized.length === 0) return false

    return ![
      "null",
      "undefined",
      "unknown",
      "unnamed",
      "unnamed building"
    ].includes(normalized)
  }

  namedTilesetColorFor(layerType) {
    if (layerType === "terrain") return "color('#355f2a', 0.99)"
    if (layerType === "roads") return "color('#1f2937', 0.99)"

    return "color('#c96a1b', 0.99)"
  }

  unnamedTilesetColorFor(layerType) {
    if (layerType === "terrain") return "color('#d7e8c8', 0.78)"
    if (layerType === "roads") return "color('#cbd5e1', 0.74)"

    return "color('#f7f8f8', 1.0)"
  }

  geojsonStyleFor(layerType) {
    if (layerType === "terrain") {
      return {
        stroke: Color.fromCssColorString("#4f6f3f"),
        strokeWidth: 1,
        fill: Color.fromCssColorString("#86a87a").withAlpha(0.75)
      }
    }

    if (layerType === "roads") {
      return {
        stroke: Color.fromCssColorString("#1f2937"),
        strokeWidth: 1,
        fill: Color.fromCssColorString("#6b7280").withAlpha(0.72)
      }
    }

    return {
      stroke: Color.fromCssColorString("#334155"),
      strokeWidth: 1,
      fill: Color.fromCssColorString("#c8c2b3").withAlpha(0.88)
    }
  }

  geojsonFillMaterialFor(layerType, entity) {
    const hasName = Boolean(entity.properties?.name?.getValue(JulianDate.now()))

    if (layerType === "terrain") {
      return hasName
        ? Color.fromCssColorString("#6f9f62").withAlpha(0.92)
        : Color.fromCssColorString("#a6c49a").withAlpha(0.85)
    }

    if (layerType === "roads") {
      return hasName
        ? Color.fromCssColorString("#4b5563").withAlpha(0.95)
        : Color.fromCssColorString("#9ca3af").withAlpha(0.86)
    }

    return hasName
      ? Color.fromCssColorString("#2f6f5e").withAlpha(0.97)
      : Color.fromCssColorString("#c8c2b3").withAlpha(0.92)
  }

  geojsonOutlineColorFor(layerType) {
    if (layerType === "terrain") return Color.fromCssColorString("#49633d")
    if (layerType === "roads") return Color.fromCssColorString("#111827")

    return Color.fromCssColorString("#5a4f3d")
  }

  setupInfoBoxSelectionHandler() {
    if (!this.viewer) return

    this.viewer.screenSpaceEventHandler.setInputAction((click) => {
      try {
        const picked = this.viewer.scene.pick(click.position)
        if (!picked) return

        const entity = this.infoEntityForPick(picked)
        if (!entity) return

        window.setTimeout(() => {
          if (!this.viewer || this.viewer.isDestroyed()) return
          this.viewer.selectedEntity = entity
        }, 0)
      } catch (_error) {
      }
    }, ScreenSpaceEventType.LEFT_CLICK)
  }

  infoEntityForPick(picked) {
    if (picked?.id?.properties) {
      return this.infoEntityForDataSourcePick(picked.id)
    }

    if (typeof picked?.getProperty !== "function") return null

    const layer = this.layerForTilesetPick(picked)
    const pickedLayerType = picked.getProperty("layer_type")
    const resolvedLayerType = layer?.layer_type || pickedLayerType || "unknown"
    const resolvedLayerName = layer?.name || this.layerLabelForType(resolvedLayerType)

    return this.infoEntityFromValues({
      layerName: resolvedLayerName,
      layerType: resolvedLayerType,
      featureId: picked.getProperty("id"),
      name: picked.getProperty("name"),
      height: picked.getProperty("height"),
      baseHeight: picked.getProperty("base_height")
    })
  }

  infoEntityForDataSourcePick(entity) {
    const props = entity.properties
    const now = JulianDate.now()

    return this.infoEntityFromValues({
      layerName: props?.layer_name?.getValue(now) || entity.name,
      layerType: props?.layer_type?.getValue(now),
      featureId: props?.id?.getValue(now),
      name: props?.name?.getValue(now),
      height: props?.height?.getValue(now),
      baseHeight: props?.base_height?.getValue(now)
    })
  }

  infoEntityFromValues(values) {
    const layerType = values.layerType || "unknown"
    const featureName = values.name || `Unnamed ${this.singularLabel(layerType)}`

    return new Entity({
      name: featureName,
      description: `
        <table class="cesium-infoBox-defaultTable"><tbody>
          <tr><th>layer</th><td>${this.escapeHtml(values.layerName || "Layer")}</td></tr>
          <tr><th>layer_type</th><td>${this.escapeHtml(layerType)}</td></tr>
          <tr><th>id</th><td>${this.escapeHtml(values.featureId ?? "-")}</td></tr>
          <tr><th>name</th><td>${this.escapeHtml(featureName)}</td></tr>
          <tr><th>height</th><td>${this.escapeHtml(values.height ?? this.defaultHeightForLayer(layerType))}</td></tr>
          <tr><th>base_height</th><td>${this.escapeHtml(values.baseHeight ?? 0)}</td></tr>
        </tbody></table>
      `
    })
  }

  layerForTilesetPick(picked) {
    const candidatePrimitives = [
      picked?.primitive,
      picked?.content?.tileset,
      picked?.tileset,
      picked?.content?.tile?.tileset
    ]

    for (const primitive of candidatePrimitives) {
      if (!primitive) continue

      for (const item of this.layerObjects.values()) {
        if (item.type === "tileset" && item.object === primitive) {
          return item.layer
        }

        if (item.type === "tileset" && item.object?.ocLayerId && primitive?.ocLayerId && item.object.ocLayerId === primitive.ocLayerId) {
          return item.layer
        }
      }
    }

    return null
  }

  singularLabel(layerType) {
    if (layerType === "terrain") return "terrain feature"
    if (layerType === "roads") return "road feature"

    return "building"
  }

  layerLabelForType(layerType) {
    if (layerType === "terrain") return "Terrain layer"
    if (layerType === "roads") return "Road layer"
    if (layerType === "buildings") return "Buildings layer"

    return "Layer"
  }

  escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
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
