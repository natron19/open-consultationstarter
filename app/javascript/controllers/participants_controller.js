import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "container", "row"]

  connect() {
    while (this.rowTargets.length < 2) {
      this.addParticipant()
    }
  }

  addParticipant() {
    const template = this.templateTarget.innerHTML
    const index = Date.now()
    const html = template.replace(/PARTICIPANT_INDEX/g, index)
    this.containerTarget.insertAdjacentHTML("beforeend", html)
  }

  removeParticipant(event) {
    const row = event.target.closest("[data-participants-target='row']")
    const destroyField = row.querySelector(".destroy-field")

    if (destroyField) {
      destroyField.value = "1"
      row.style.display = "none"
    } else {
      row.remove()
    }
  }
}
