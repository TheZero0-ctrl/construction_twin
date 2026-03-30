import { Application } from "@hotwired/stimulus"
import { Slideover } from "tailwindcss-stimulus-components"

const application = Application.start()
application.register("slideover", Slideover)

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

export { application }
