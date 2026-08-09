/** Build instruction keys the same way the API does. */

export function buildInstructionKey(params: {
  operation: string
  direction?: string
  mode?: string
  style?: string
}): string | null {
  const operation = params.operation.trim().toLowerCase()

  switch (operation) {
    case 'translate': {
      const mode = (params.mode ?? '').trim().toLowerCase()
      if (!mode) return null
      if (params.direction === 'en-fa') return `en-to-fa-${mode}`
      if (params.direction === 'fa-en') return `fa-to-en-${mode}`
      return null
    }
    case 'simplify':
      return 'simplify-en'
    case 'term': {
      const style = (params.style ?? '').trim().toLowerCase()
      return style ? `term-for-${style}` : null
    }
    case 'refine': {
      const style = (params.style ?? '').trim().toLowerCase()
      return style ? `refine-to-${style}` : null
    }
    case 'symptoms':
      return 'symptoms'
    case 'compare':
      return 'compare-en'
    default:
      return null
  }
}

/** Display helper — keep API keys as en/fa; show English/Persian in the UI. */
export function formatInstructionKey(key: string): string {
  return key
    .replace(/(^|[-_])en(?=[-_]|$)/gi, '$1English')
    .replace(/(^|[-_])fa(?=[-_]|$)/gi, '$1Persian')
}
