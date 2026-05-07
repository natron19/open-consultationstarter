import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.savedHtml = null
    this.formSubmission = null
  }

  showLoading(event) {
    this.savedHtml = this.element.innerHTML
    this.formSubmission = event.detail.formSubmission
    this.element.innerHTML = this.loadingHtml()
  }

  cancelGeneration() {
    if (this.formSubmission) {
      this.formSubmission.stop()
      this.formSubmission = null
    }
    if (this.savedHtml) {
      this.element.innerHTML = this.savedHtml
      this.savedHtml = null
    }
  }

  loadingHtml() {
    return `<div class="card bg-dark border-secondary">
      <div class="card-body text-center py-5">
        <div class="spinner-border mb-3" style="color: var(--accent);" role="status">
          <span class="visually-hidden">Generating…</span>
        </div>
        <p class="text-muted mb-3">Generating your consultation plan…<br>
          <span class="small">This usually takes 10–20 seconds.</span>
        </p>
        <button type="button"
                class="btn btn-sm btn-outline-secondary"
                data-action="click->plan-generate#cancelGeneration">
          Cancel
        </button>
      </div>
    </div>`
  }
}
