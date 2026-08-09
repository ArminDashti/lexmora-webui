<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { api } from '../api/client'
import MarkdownPreview from '../components/MarkdownPreview.vue'
import { buildInstructionKey, formatInstructionKey } from '../utils/instructionKey'
import { textDir } from '../utils/textDirection'

const route = useRoute()

const content = ref('')
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const saved = ref(false)
const loaded = ref(false)
const viewMode = ref<'preview' | 'edit'>('preview')

const operation = computed(() => String(route.params.operation ?? '').trim().toLowerCase())

const instructionKey = computed(() =>
  buildInstructionKey({
    operation: operation.value,
    direction: typeof route.query.direction === 'string' ? route.query.direction : undefined,
    mode: typeof route.query.mode === 'string' ? route.query.mode : undefined,
    style: typeof route.query.style === 'string' ? route.query.style : undefined,
  })
)

async function load() {
  const key = instructionKey.value
  loaded.value = false
  saved.value = false

  if (!key) {
    content.value = ''
    error.value = 'Missing operation details for this instruction'
    loading.value = false
    return
  }

  loading.value = true
  error.value = ''
  try {
    const item = await api.getInstruction(key)
    content.value = item.content
    loaded.value = true
    viewMode.value = 'preview'
  } catch (e) {
    content.value = ''
    error.value = e instanceof Error ? e.message : 'Failed to load instruction'
  } finally {
    loading.value = false
  }
}

async function save() {
  const key = instructionKey.value
  if (!key || !loaded.value) return
  saving.value = true
  error.value = ''
  saved.value = false
  try {
    const updated = await api.updateInstruction(key, content.value)
    content.value = updated.content
    saved.value = true
    viewMode.value = 'preview'
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Save failed'
  } finally {
    saving.value = false
  }
}

watch(
  () => [route.params.operation, route.query.direction, route.query.mode, route.query.style],
  () => {
    void load()
  },
  { immediate: true }
)
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <RouterLink to="/transform" class="btn-ghost inline-block text-sm">
        ← Back to Transform
      </RouterLink>
    </div>

    <div v-if="loading" class="text-gray-500">Loading...</div>

    <div v-else class="card space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h3 class="font-medium text-white">
          {{ instructionKey ? formatInstructionKey(instructionKey) : 'Instruction' }}
        </h3>
        <div v-if="loaded" class="flex gap-1 rounded-lg border border-surface-border p-0.5">
          <button
            type="button"
            class="rounded-md px-3 py-1 text-sm transition"
            :class="viewMode === 'preview' ? 'bg-accent/20 text-accent' : 'text-gray-400 hover:text-white'"
            @click="viewMode = 'preview'"
          >
            Preview
          </button>
          <button
            type="button"
            class="rounded-md px-3 py-1 text-sm transition"
            :class="viewMode === 'edit' ? 'bg-accent/20 text-accent' : 'text-gray-400 hover:text-white'"
            @click="viewMode = 'edit'"
          >
            Edit
          </button>
        </div>
      </div>

      <template v-if="loaded">
        <MarkdownPreview v-if="viewMode === 'preview'" :content="content" />
        <textarea
          v-else
          v-model="content"
          rows="16"
          class="input-field font-mono text-sm"
          :dir="textDir(content)"
        />

        <div class="flex items-center gap-4">
          <button
            type="button"
            class="btn-primary"
            :disabled="saving || viewMode === 'preview'"
            @click="save"
          >
            {{ saving ? 'Saving...' : 'Save' }}
          </button>
          <span v-if="saved" class="text-sm text-green-400">Saved</span>
        </div>
      </template>

      <p v-if="error" class="text-sm text-red-400">{{ error }}</p>
    </div>
  </div>
</template>
