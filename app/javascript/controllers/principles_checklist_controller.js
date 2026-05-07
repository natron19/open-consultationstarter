import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]
  static values = { consultationId: String }

  connect() {
    const stored = localStorage.getItem(this.storageKey)
    if (!stored) return
    const checked = JSON.parse(stored)
    this.checkboxTargets.forEach((cb, i) => {
      cb.checked = checked.includes(i)
    })
  }

  save() {
    const checked = this.checkboxTargets
      .map((cb, i) => cb.checked ? i : null)
      .filter(i => i !== null)
    localStorage.setItem(this.storageKey, JSON.stringify(checked))
  }

  get storageKey() {
    return `cs_principles_${this.consultationIdValue}`
  }
}
