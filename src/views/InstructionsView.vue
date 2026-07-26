<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { api, type Instruction } from '../api/client'
import MarkdownPreview from '../components/MarkdownPreview.vue'
import { textDir } from '../utils/textDirection'

const instructions = ref<Instruction[]>([])
const selectedKey = ref('')
const content = ref('')
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const saved = ref(false)
const viewMode = ref<'preview' | 'edit'>('preview')

async function load() {
  loading.value = true
  error.value = ''
  try {
    instructions.value = await api.getInstructions()
    if (!selectedKey.value && instructions.value.length > 0) {
      select(instructions.value[0].key)
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
    saved.value = true
    viewMode.value = 'preview'
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Save failed'
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="space-y-6">
    <div v-if="loading" class="text-gray-500">Loading...</div>

    <div v-else class="grid gap-6 lg:grid-cols-[240px_1fr]">
      <div class="card max-h-[70vh] overflow-y-auto p-3">
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
          {{ item.key }}
        </button>
      </div>

      <div class="card space-y-4">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <h3 class="font-medium text-white">{{ selectedKey }}</h3>
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
      </div>
    </div>
  </div>
</template>
