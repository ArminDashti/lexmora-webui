<script setup lang="ts">
import { RouterLink, RouterView, useRoute } from 'vue-router'
import { clearAuth, getUsername } from '../api/client'

const route = useRoute()
const username = getUsername() || 'armin'

const links = [
  { to: '/transform', label: 'Transform' },
  { to: '/history', label: 'History' },
  { to: '/stats', label: 'Stats' },
  { to: '/settings', label: 'Settings' },
]

function logout() {
  clearAuth()
  window.location.href = '/login'
}
</script>

<template>
  <div class="flex min-h-dvh flex-col bg-surface">
    <header class="shrink-0 border-b border-surface-border bg-surface-raised">
      <div class="mx-auto flex max-w-6xl items-center justify-between px-4 py-4">
        <div class="flex items-center gap-8">
          <RouterLink
            to="/transform"
            class="flex shrink-0 items-center gap-2.5"
            aria-label="Lexmora home"
          >
            <img
              src="/logo-mark.png"
              alt=""
              class="h-11 w-auto object-contain"
              width="80"
              height="44"
            />
            <span class="text-lg font-semibold tracking-tight text-white">Lexmora</span>
          </RouterLink>
          <nav class="flex gap-1">
            <RouterLink
              v-for="link in links"
              :key="link.to"
              :to="link.to"
              class="rounded-lg px-3 py-2 text-sm transition"
              :class="
                route.path === link.to
                  ? 'bg-accent/20 text-accent'
                  : 'text-gray-400 hover:bg-surface-border/50 hover:text-white'
              "
            >
              {{ link.label }}
            </RouterLink>
          </nav>
        </div>
        <div class="flex items-center gap-4">
          <span class="text-sm text-gray-400">{{ username }}</span>
          <button class="btn-ghost text-sm" @click="logout">Logout</button>
        </div>
      </div>
    </header>

    <main class="mx-auto w-full max-w-6xl flex-1 px-4 py-8">
      <RouterView />
    </main>

    <footer
      class="grid shrink-0 grid-cols-[auto_1fr_auto] items-center gap-3 border-t border-surface-border px-4 py-3 sm:px-5"
    >
      <a
        class="inline-flex h-10 w-10 items-center justify-center text-gray-300 transition hover:text-accent"
        href="https://github.com/ArminDashti"
        target="_blank"
        rel="noopener noreferrer"
        aria-label="Armin Dashti on GitHub"
      >
        <svg
          viewBox="0 0 16 16"
          width="22"
          height="22"
          aria-hidden="true"
          focusable="false"
          fill="currentColor"
        >
          <path
            d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"
          />
        </svg>
      </a>
      <p class="m-0 text-center text-xs text-gray-500 sm:text-sm">
        © 2026 Dashti Technologies (Armin Dashti)
      </p>
      <span class="block h-10 w-10" aria-hidden="true" />
    </footer>
  </div>
</template>
