<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { api, type Instruction } from '../api/client'
import MarkdownPreview from '../components/MarkdownPreview.vue'
import { textDir } from '../utils/textDirection'

const CREATE_OPERATIONS = [
  { value: 'translate', label: 'Translate' },
  { value: 'simplify', label: 'Simplify' },
  { value: 'term', label: 'Term' },
  { value: 'refine', label: 'Refine' },
  { value: 'symptoms', label: 'Symptoms' },
  { value: 'compare', label: 'Compare' },
]

const DIRECTIONS = [
  { value: 'en-fa', label: 'English → Persian' },
  { value: 'fa-en', label: 'Persian → English' },
]

const COMPARE_LANGUAGES = [
  { value: 'en', label: 'English' },
  { value: 'fa', label: 'Persian' },
]

/** Display helper — keep API keys as en/fa; show English/Persian in the UI. */
function formatInstructionKey(key: string): string {
  return key
    .replace(/(^|[-_])en(?=[-_]|$)/gi, '$1English')
    .replace(/(^|[-_])fa(?=[-_]|$)/gi, '$1Persian')
}

const instructions = ref<Instruction[]>([])
const selectedKey = ref('')
const content = ref('')
const loading = ref(true)
const saving = ref(false)
const creating = ref(false)
const error = ref('')
const saved = ref(false)
const createError = ref('')
const viewMode = ref<'preview' | 'edit'>('preview')
const showCreate = ref(false)

const createOperation = ref('translate')
const createDirection = ref('en-fa')
const createMode = ref('')
const createStyle = ref('')
const createLanguage = ref('en')

const needsMode = computed(() => createOperation.value === 'translate')
const needsStyle = computed(
  () => createOperation.value === 'term' || createOperation.value === 'refine'
)
const needsDirection = computed(() => createOperation.value === 'translate')
const needsLanguage = computed(() => createOperation.value === 'compare')
const isFixedKey = computed(
  () => createOperation.value === 'simplify' || createOperation.value === 'symptoms'
)

async function load() {
  loading.value = true
  error.value = ''
  try {
    instructions.value = await api.getInstructions()
    if (!selectedKey.value && instructions.value.length > 0) {
      select(instructions.value[0].key)
    } else if (selectedKey.value) {
      const item = instructions.value.find((i) => i.key === selectedKey.value)
      if (item) content.value = item.content
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load instructions'
  } finally {
    loading.value = false
  }
}

function select(key: string) {
  selectedKey.value = key
  const item = instructions.value.find((i) => i.key === key)
  content.value = item?.content || ''
  saved.value = false
  viewMode.value = 'preview'
}

async function save() {
  if (!selectedKey.value) return
  saving.value = true
  error.value = ''
  saved.value = false
  try {
    const updated = await api.updateInstruction(selectedKey.value, content.value)
    const idx = instructions.value.findIndex((i) => i.key === updated.key)
    if (idx >= 0) instructions.value[idx] = updated
    else instructions.value.push(updated)
    saved.value = true
    viewMode.value = 'preview'
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Save failed'
  } finally {
    saving.value = false
  }
}

async function create() {
  creating.value = true
  createError.value = ''
  try {
    const payload: Parameters<typeof api.createInstruction>[0] = {
      operation: createOperation.value,
    }
    if (needsDirection.value) payload.direction = createDirection.value
    if (needsMode.value) payload.mode = createMode.value.trim()
    if (needsStyle.value) payload.style = createStyle.value.trim()
    if (needsLanguage.value) payload.language = createLanguage.value

    const created = await api.createInstruction(payload)
    const idx = instructions.value.findIndex((i) => i.key === created.key)
    if (idx >= 0) instructions.value[idx] = created
    else {
      instructions.value.push(created)
      instructions.value.sort((a, b) => a.key.localeCompare(b.key))
    }
    select(created.key)
    viewMode.value = 'edit'
    showCreate.value = false
    createMode.value = ''
    createStyle.value = ''
  } catch (e) {
    createError.value = e instanceof Error ? e.message : 'Create failed'
  } finally {
    creating.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="space-y-6">
    <div v-if="loading" class="text-gray-500">Loading...</div>

    <div v-else class="grid gap-6 lg:grid-cols-[280px_1fr]">
      <div class="space-y-3">
        <div class="card max-h-[60vh] overflow-y-auto p-3">
          <button
            v-for="item in instructions"
            :key="item.key"
            class="mb-1 block w-full rounded-lg px-3 py-2 text-left text-sm transition"
            :class="
              selectedKey === item.key
                ? 'bg-accent/20 text-accent'
                : 'text-gray-400 hover:bg-surface hover:text-white'
            "
            @click="select(item.key)"
          >
            {{ formatInstructionKey(item.key) }}
          </button>
        </div>

        <div class="card space-y-3 p-3">
          <button
            type="button"
            class="text-sm text-accent hover:underline"
            @click="showCreate = !showCreate"
          >
            {{ showCreate ? 'Hide create form' : '+ Create operation / mode' }}
          </button>

          <div v-if="showCreate" class="space-y-3">
            <div>
              <label class="mb-1 block text-xs text-gray-400">Operation</label>
              <select v-model="createOperation" class="select-field select-compact">
                <option v-for="op in CREATE_OPERATIONS" :key="op.value" :value="op.value">
                  {{ op.label }}
                </option>
              </select>
            </div>

            <div v-if="needsDirection">
              <label class="mb-1 block text-xs text-gray-400">Direction</label>
              <select v-model="createDirection" class="select-field select-compact">
                <option v-for="d in DIRECTIONS" :key="d.value" :value="d.value">
                  {{ d.label }}
                </option>
              </select>
            </div>

            <div v-if="needsMode">
              <label class="mb-1 block text-xs text-gray-400">Mode slug</label>
              <input
                v-model="createMode"
                class="input-field"
                placeholder="e.g. poetry"
              />
              <p class="mt-1 text-xs text-gray-500">Lowercase letters, numbers, hyphens</p>
            </div>

            <div v-if="needsStyle">
              <label class="mb-1 block text-xs text-gray-400">Style slug</label>
              <input
                v-model="createStyle"
                class="input-field"
                placeholder="e.g. academic"
              />
            </div>

            <div v-if="needsLanguage">
              <label class="mb-1 block text-xs text-gray-400">Language</label>
              <select v-model="createLanguage" class="select-field select-compact">
                <option v-for="l in COMPARE_LANGUAGES" :key="l.value" :value="l.value">
                  {{ l.label }}
                </option>
              </select>
            </div>

            <p v-if="isFixedKey" class="text-xs text-gray-500">
              Creates or refreshes the fixed key for this operation.
            </p>

            <button
              type="button"
              class="btn-primary w-full"
              :disabled="creating || (needsMode && !createMode.trim()) || (needsStyle && !createStyle.trim())"
              @click="create"
            >
              {{ creating ? 'Creating...' : 'Create' }}
            </button>
            <p v-if="createError" class="text-sm text-red-400">{{ createError }}</p>
          </div>
        </div>
      </div>

      <div class="card space-y-4">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <h3 class="font-medium text-white">
            {{ selectedKey ? formatInstructionKey(selectedKey) : 'Select an instruction' }}
          </h3>
          <div class="flex gap-1 rounded-lg border border-surface-border p-0.5">
            <button
              class="rounded-md px-3 py-1 text-sm transition"
              :class="viewMode === 'preview' ? 'bg-accent/20 text-accent' : 'text-gray-400 hover:text-white'"
              @click="viewMode = 'preview'"
            >
              Preview
            </button>
            <button
              class="rounded-md px-3 py-1 text-sm transition"
              :class="viewMode === 'edit' ? 'bg-accent/20 text-accent' : 'text-gray-400 hover:text-white'"
              @click="viewMode = 'edit'"
            >
              Edit
            </button>
          </div>
        </div>

        <template v-if="selectedKey">
          <MarkdownPreview v-if="viewMode === 'preview'" :content="content" />
          <textarea
            v-else
            v-model="content"
            rows="16"
            class="input-field font-mono text-sm"
            :dir="textDir(content)"
          />

          <div class="flex items-center gap-4">
            <button class="btn-primary" :disabled="saving || viewMode === 'preview'" @click="save">
              {{ saving ? 'Saving...' : 'Save' }}
            </button>
            <span v-if="saved" class="text-sm text-green-400">Saved</span>
            <span v-if="error" class="text-sm text-red-400">{{ error }}</span>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>
