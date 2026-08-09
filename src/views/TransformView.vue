<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink } from 'vue-router'
import {
  api,
  type OperationOption,
  type TransformOptions,
  type TransformResult,
} from '../api/client'
import MarkdownPreview from '../components/MarkdownPreview.vue'
import { formatLocalDateTime } from '../utils/datetime'
import { startsWithPersian, textDir } from '../utils/textDirection'

const options = ref<TransformOptions | null>(null)
const operation = ref('')
const text = ref('')
const text1 = ref('')
const text2 = ref('')
const direction = ref('')
const mode = ref('')
const movieName = ref('')
const style = ref('')
const language = ref('')

const loading = ref(false)
const optionsLoading = ref(true)
const error = ref('')
const pasteError = ref('')
const result = ref<TransformResult | null>(null)

const currentOp = computed<OperationOption | undefined>(() =>
  options.value?.operations.find((o) => o.value === operation.value)
)

const directions = computed(() => currentOp.value?.directions ?? [])

const currentDirection = computed(() =>
  directions.value.find((d) => d.value === direction.value)
)

const modes = computed(() => currentDirection.value?.modes ?? [])

const styles = computed(() => currentOp.value?.styles ?? [])

const showMovieField = computed(
  () => operation.value === 'translate' && mode.value === 'movie'
)

const canSubmit = computed(() => {
  if (operation.value === 'compare') {
    return text1.value.trim().length > 0 && text2.value.trim().length > 0
  }
  return text.value.trim().length > 0 && !!operation.value
})

const inputDir = computed(() => textDir(text.value))
const text1Dir = computed(() => textDir(text1.value))
const text2Dir = computed(() => textDir(text2.value))

const resultDate = computed(() =>
  result.value
    ? formatLocalDateTime(result.value.created_at, result.value.formatted_date)
    : ''
)

const instructionLink = computed(() => {
  if (!operation.value) return { name: 'instructions' as const }
  const query: Record<string, string> = {}
  if (operation.value === 'translate') {
    if (direction.value) query.direction = direction.value
    if (mode.value) query.mode = mode.value
  } else if (operation.value === 'term' || operation.value === 'refine') {
    if (style.value) query.style = style.value
  }
  return {
    name: 'instructions' as const,
    params: { operation: operation.value },
    query,
  }
})

function pickModeDefault(modeList: { value: string }[]): string {
  const general = modeList.find((m) => m.value.toLowerCase() === 'general')
  return general?.value ?? modeList[0]?.value ?? ''
}

function pickDefaults(ops: OperationOption[]) {
  if (!ops.length) {
    operation.value = ''
    return
  }
  if (!ops.some((o) => o.value === operation.value)) {
    operation.value = ops[0].value
  }
  syncSecondaryFields()
}

function syncSecondaryFields() {
  const op = currentOp.value
  if (!op) return

  if (op.directions?.length) {
    if (!op.directions.some((d) => d.value === direction.value)) {
      direction.value = op.directions[0].value
    }
    const dir = op.directions.find((d) => d.value === direction.value)
    if (dir?.modes.length) {
      mode.value = pickModeDefault(dir.modes)
    } else {
      mode.value = ''
    }
  } else {
    direction.value = ''
    mode.value = ''
  }

  if (op.styles?.length) {
    if (!op.styles.some((s) => s.value === style.value)) {
      style.value = op.styles[0].value
    }
  } else {
    style.value = ''
  }

  if (operation.value === 'term') {
    if (language.value !== 'en' && language.value !== 'fa') {
      language.value = 'en'
    }
  } else if (operation.value === 'compare') {
    language.value = 'en'
  } else {
    language.value = ''
  }
}

function syncDirectionFromText(input: string) {
  if (!input.trim()) return

  if (operation.value === 'translate' && directions.value.length) {
    const target = startsWithPersian(input) ? 'fa-en' : 'en-fa'
    if (directions.value.some((d) => d.value === target) && direction.value !== target) {
      direction.value = target
    }
    return
  }

  if (operation.value === 'term') {
    language.value = startsWithPersian(input) ? 'fa' : 'en'
  }
}

watch(operation, syncSecondaryFields)
watch(direction, syncSecondaryFields)
watch(text, (value) => syncDirectionFromText(value))
watch(operation, () => {
  if (text.value.trim()) syncDirectionFromText(text.value)
})

async function loadOptions() {
  optionsLoading.value = true
  error.value = ''
  try {
    options.value = await api.getTransformOptions()
    pickDefaults(options.value.operations)
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load options'
  } finally {
    optionsLoading.value = false
  }
}

async function pasteFromClipboard() {
  pasteError.value = ''
  try {
    if (!navigator.clipboard?.readText) {
      pasteError.value = 'Clipboard paste is not available in this browser'
      return
    }
    const clipped = await navigator.clipboard.readText()
    if (!clipped) {
      pasteError.value = 'Clipboard is empty'
      return
    }

    if (operation.value === 'compare') {
      if (!text1.value.trim()) text1.value = clipped
      else if (!text2.value.trim()) text2.value = clipped
      else text1.value = clipped
      return
    }

    text.value = clipped
  } catch {
    pasteError.value = 'Could not read clipboard — allow paste permission and try again'
  }
}

async function submit() {
  if (!canSubmit.value || loading.value) return
  error.value = ''
  pasteError.value = ''
  result.value = null
  loading.value = true

  const payload: Record<string, unknown> = {
    operation: operation.value,
  }

  if (operation.value === 'compare') {
    payload.text1 = text1.value
    payload.text2 = text2.value
    payload.language = 'en'
  } else {
    payload.text = text.value

    if (operation.value === 'translate') {
      payload.direction = direction.value
      payload.mode = mode.value
      if (showMovieField.value && movieName.value.trim()) {
        payload.movie_name = movieName.value.trim()
      }
    } else if (operation.value === 'term') {
      payload.style = style.value
      if (language.value) payload.language = language.value
    } else if (operation.value === 'refine') {
      payload.style = style.value
    }
  }

  try {
    result.value = await api.transform(payload)
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Transform failed'
  } finally {
    loading.value = false
  }
}

function onSubmitKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault()
    submit()
  }
}

onMounted(loadOptions)
</script>

<template>
  <div class="space-y-6">
    <form class="card space-y-4" @submit.prevent="submit">
      <div v-if="optionsLoading" class="text-sm text-gray-500">Loading options...</div>

      <div v-else class="flex flex-wrap items-end gap-3">
        <div class="w-full max-w-[11rem]">
          <label class="mb-1 block text-sm text-gray-400">Operation</label>
          <select v-model="operation" class="select-field select-compact">
            <option
              v-for="op in options?.operations ?? []"
              :key="op.value"
              :value="op.value"
            >
              {{ op.label }}
            </option>
          </select>
        </div>

        <template v-if="directions.length">
          <div class="w-full max-w-[14rem]">
            <label class="mb-1 block text-sm text-gray-400">Direction</label>
            <select v-model="direction" class="select-field select-compact">
              <option v-for="d in directions" :key="d.value" :value="d.value">
                {{ d.label }}
              </option>
            </select>
          </div>
          <div v-if="modes.length" class="w-full max-w-[11rem]">
            <label class="mb-1 block text-sm text-gray-400">Mode</label>
            <select v-model="mode" class="select-field select-compact">
              <option v-for="m in modes" :key="m.value" :value="m.value">
                {{ m.label }}
              </option>
            </select>
          </div>
        </template>

        <template v-if="styles.length">
          <div class="w-full max-w-[11rem]">
            <label class="mb-1 block text-sm text-gray-400">Style</label>
            <select v-model="style" class="select-field select-compact">
              <option v-for="s in styles" :key="s.value" :value="s.value">
                {{ s.label }}
              </option>
            </select>
          </div>
        </template>

        <div class="ml-auto flex items-center gap-2">
          <button class="btn-ghost text-sm" type="button" @click="pasteFromClipboard">
            Paste
          </button>
          <RouterLink :to="instructionLink" class="btn-ghost inline-block text-sm">
            Instruction
          </RouterLink>
        </div>
      </div>

      <div v-if="showMovieField" class="max-w-md">
        <label class="mb-1 block text-sm text-gray-400">Movie name (optional)</label>
        <input v-model="movieName" class="input-field" placeholder="e.g. The Godfather" />
      </div>

      <template v-if="operation === 'compare'">
        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <label class="mb-1 block text-sm text-gray-400">First word / phrase</label>
            <input
              v-model="text1"
              class="input-field"
              :dir="text1Dir"
              placeholder="e.g. ask"
              @keydown="onSubmitKeydown"
            />
          </div>
          <div>
            <label class="mb-1 block text-sm text-gray-400">Second word / phrase</label>
            <input
              v-model="text2"
              class="input-field"
              :dir="text2Dir"
              placeholder="e.g. request"
              @keydown="onSubmitKeydown"
            />
          </div>
        </div>
      </template>

      <div v-else>
        <label class="mb-1 block text-sm text-gray-400">Input text</label>
        <textarea
          v-model="text"
          rows="6"
          class="input-field resize-y"
          :dir="inputDir"
          placeholder="Enter text to transform... (Enter to submit, Shift+Enter for newline)"
          @keydown="onSubmitKeydown"
        />
      </div>

      <p v-if="pasteError" class="text-sm text-red-400">{{ pasteError }}</p>
      <p v-if="error" class="text-sm text-red-400">{{ error }}</p>

      <button class="btn-primary" type="submit" :disabled="loading || !canSubmit">
        {{ loading ? 'Processing...' : 'Transform' }}
      </button>
    </form>

    <div v-if="result" class="card space-y-3">
      <div class="flex flex-wrap items-center gap-3 text-sm text-gray-400">
        <span class="rounded bg-accent/20 px-2 py-0.5 text-accent">{{ result.type_display }}</span>
        <span>{{ result.model }}</span>
        <span>{{ resultDate }}</span>
      </div>
      <div>
        <h3 class="mb-1 text-sm font-medium text-gray-400">Result</h3>
        <MarkdownPreview :content="result.result_text" />
      </div>
    </div>
  </div>
</template>
