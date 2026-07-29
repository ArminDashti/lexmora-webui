<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { api, type HistoryRecord } from '../api/client'
import HistoryModal from '../components/HistoryModal.vue'
import { formatLocalDateTime } from '../utils/datetime'

const HISTORY_TYPES = [
  { value: '', label: 'All types' },
  { value: 'simplify', label: 'Simplify' },
  { value: 'en_fa', label: 'English-Persian' },
  { value: 'fa_en', label: 'Persian-English' },
  { value: 'term_en', label: 'Term English' },
  { value: 'term_fa', label: 'Term Persian' },
  { value: 'refine', label: 'Refine' },
  { value: 'symptoms', label: 'Symptoms' },
  { value: 'compare_en', label: 'Compare English' },
  { value: 'compare_fa', label: 'Compare Persian' },
]

const items = ref<HistoryRecord[]>([])
const loading = ref(true)
const error = ref('')
const sortBy = ref('datetime')
const sortOrder = ref('desc')
const typeFilter = ref('')
const fromDate = ref('')
const toDate = ref('')
const selected = ref<HistoryRecord | null>(null)
const checkedIds = ref<Set<string>>(new Set())
const deleting = ref(false)

const showFilters = computed(
  () => items.value.length > 0 || !!typeFilter.value || !!fromDate.value || !!toDate.value
)

const allChecked = computed(
  () => items.value.length > 0 && items.value.every((item) => checkedIds.value.has(item.id))
)

const someChecked = computed(() => checkedIds.value.size > 0)

function displayDate(item: HistoryRecord) {
  return formatLocalDateTime(item.created_at, item.formatted_date)
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    items.value = await api.getHistory({
      sort_by: sortBy.value,
      sort_order: sortOrder.value,
      type: typeFilter.value || undefined,
      from: fromDate.value || undefined,
      to: toDate.value || undefined,
    })
    const visible = new Set(items.value.map((i) => i.id))
    checkedIds.value = new Set([...checkedIds.value].filter((id) => visible.has(id)))
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load history'
  } finally {
    loading.value = false
  }
}

function toggleSort(column: string) {
  if (sortBy.value === column) {
    sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortBy.value = column
    sortOrder.value = column === 'datetime' ? 'desc' : 'asc'
  }
  load()
}

function toggleCheck(id: string, event: Event) {
  event.stopPropagation()
  const next = new Set(checkedIds.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  checkedIds.value = next
}

function toggleSelectAll(event: Event) {
  const target = event.target as HTMLInputElement
  if (target.checked) {
    checkedIds.value = new Set(items.value.map((i) => i.id))
  } else {
    checkedIds.value = new Set()
  }
}

async function remove(id: string, event: Event) {
  event.stopPropagation()
  if (!confirm('Delete this history entry?')) return
  try {
    await api.deleteHistory(id)
    items.value = items.value.filter((i) => i.id !== id)
    const next = new Set(checkedIds.value)
    next.delete(id)
    checkedIds.value = next
    if (selected.value?.id === id) selected.value = null
  } catch (e) {
    alert(e instanceof Error ? e.message : 'Delete failed')
  }
}

async function removeChecked() {
  if (!checkedIds.value.size) return
  const count = checkedIds.value.size
  if (!confirm(`Delete ${count} selected histor${count === 1 ? 'y entry' : 'y entries'}?`)) return

  deleting.value = true
  error.value = ''
  const ids = [...checkedIds.value]
  const results = await Promise.allSettled(ids.map((id) => api.deleteHistory(id)))
  const failed = results.filter((r) => r.status === 'rejected').length
  const deleted = new Set(ids.filter((_, i) => results[i].status === 'fulfilled'))

  items.value = items.value.filter((i) => !deleted.has(i.id))
  checkedIds.value = new Set([...checkedIds.value].filter((id) => !deleted.has(id)))
  if (selected.value && deleted.has(selected.value.id)) selected.value = null

  if (failed) {
    error.value = `Failed to delete ${failed} of ${ids.length} entries`
  }
  deleting.value = false
}

function sortIcon(column: string) {
  if (sortBy.value !== column) return '↕'
  return sortOrder.value === 'asc' ? '↑' : '↓'
}

function clearFilters() {
  typeFilter.value = ''
  fromDate.value = ''
  toDate.value = ''
  load()
}

onMounted(load)
</script>

<template>
  <div class="space-y-6">
    <div v-if="error" class="text-sm text-red-400">{{ error }}</div>

    <div v-if="showFilters" class="card flex flex-wrap items-end gap-3">
      <div class="w-full max-w-[14rem]">
        <label class="mb-1 block text-sm text-gray-400">Type</label>
        <select v-model="typeFilter" class="select-field select-compact" @change="load">
          <option v-for="t in HISTORY_TYPES" :key="t.value || 'all'" :value="t.value">
            {{ t.label }}
          </option>
        </select>
      </div>
      <div class="w-full max-w-[11rem]">
        <label class="mb-1 block text-sm text-gray-400">From</label>
        <input v-model="fromDate" type="date" class="input-field" @change="load" />
      </div>
      <div class="w-full max-w-[11rem]">
        <label class="mb-1 block text-sm text-gray-400">To</label>
        <input v-model="toDate" type="date" class="input-field" @change="load" />
      </div>
      <button
        v-if="fromDate || toDate || typeFilter"
        type="button"
        class="text-sm text-gray-400 hover:text-white"
        @click="clearFilters"
      >
        Clear filters
      </button>
      <button
        type="button"
        class="btn-danger ml-auto"
        :disabled="!someChecked || deleting"
        @click="removeChecked"
      >
        {{ deleting ? 'Deleting...' : 'Delete' }}
      </button>
    </div>

    <div class="card overflow-hidden p-0">
      <div class="overflow-x-auto">
        <table class="w-full text-left text-sm">
          <thead class="border-b border-surface-border bg-surface text-gray-400">
            <tr>
              <th class="w-10 px-4 py-3">
                <input
                  type="checkbox"
                  class="accent-accent"
                  :checked="allChecked"
                  :disabled="items.length === 0"
                  @click.stop
                  @change="toggleSelectAll"
                />
              </th>
              <th class="cursor-pointer px-4 py-3 hover:text-white" @click="toggleSort('type')">
                Type {{ sortIcon('type') }}
              </th>
              <th class="px-4 py-3">Input</th>
              <th class="px-4 py-3">Result</th>
              <th class="cursor-pointer px-4 py-3 hover:text-white" @click="toggleSort('model')">
                Model {{ sortIcon('model') }}
              </th>
              <th class="cursor-pointer px-4 py-3 hover:text-white" @click="toggleSort('datetime')">
                DateTime {{ sortIcon('datetime') }}
              </th>
              <th class="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="loading">
              <td colspan="7" class="px-4 py-8 text-center text-gray-500">Loading...</td>
            </tr>
            <tr v-else-if="items.length === 0">
              <td colspan="7" class="px-4 py-8 text-center text-gray-500">No history yet</td>
            </tr>
            <tr
              v-for="item in items"
              :key="item.id"
              class="cursor-pointer border-b border-surface-border transition hover:bg-surface"
              @click="selected = item"
            >
              <td class="px-4 py-3" @click.stop>
                <input
                  type="checkbox"
                  class="accent-accent"
                  :checked="checkedIds.has(item.id)"
                  @change="toggleCheck(item.id, $event)"
                />
              </td>
              <td class="px-4 py-3">
                <span class="table-cell-truncate block">{{ item.type_display }}</span>
              </td>
              <td class="px-4 py-3">
                <span class="table-cell-truncate block" :title="item.input_text">{{
                  item.input_text
                }}</span>
              </td>
              <td class="px-4 py-3">
                <span class="table-cell-truncate block" :title="item.result_text">{{
                  item.result_text
                }}</span>
              </td>
              <td class="px-4 py-3">
                <span class="table-cell-truncate block">{{ item.model }}</span>
              </td>
              <td class="px-4 py-3 whitespace-nowrap">{{ displayDate(item) }}</td>
              <td class="px-4 py-3">
                <button
                  class="text-red-400 hover:text-red-300"
                  title="Delete"
                  @click="remove(item.id, $event)"
                >
                  ✕
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <HistoryModal v-if="selected" :item="selected" @close="selected = null" />
  </div>
</template>
