<template>
  <div>
    <!-- Top App Bar -->
    <v-app-bar color="primary" density="comfortable" elevation="2">
      <v-app-bar-nav-icon @click="appStore.toggleSidebar()" />
      <v-toolbar-title class="text-subtitle-1 font-weight-bold">
        <v-icon class="mr-2">mdi-scissors-cutting</v-icon>
        Tailor Admin
      </v-toolbar-title>
      <v-spacer />
      <v-chip class="mr-3" color="secondary" variant="flat" size="small">
        <v-icon start size="small">mdi-account</v-icon>
        {{ authStore.userName }}
      </v-chip>
      <v-btn icon @click="authStore.logout()">
        <v-icon>mdi-logout</v-icon>
        <v-tooltip activator="parent" location="bottom">Logout</v-tooltip>
      </v-btn>
    </v-app-bar>

    <!-- Side Navigation -->
    <v-navigation-drawer
      v-model="appStore.sidebarOpen"
      color="primary-darken-1"
      theme="dark"
      width="260"
    >
      <v-list-item
        class="pa-4"
        prepend-icon="mdi-scissors-cutting"
        title="Tailor Business"
        subtitle="Admin Panel"
      />
      <v-divider />
      <v-list density="compact" nav>
        <v-list-item
          v-for="item in navItems"
          :key="item.to"
          :to="item.to"
          :prepend-icon="item.icon"
          :title="item.title"
          rounded="lg"
          class="mb-1"
        />
        <v-divider class="my-2" />
        <v-list-subheader>Reports</v-list-subheader>
        <v-list-item
          v-for="item in reportItems"
          :key="item.to"
          :to="item.to"
          :prepend-icon="item.icon"
          :title="item.title"
          rounded="lg"
          class="mb-1"
        />
        <v-divider class="my-2" />
        <v-list-item to="/settings" prepend-icon="mdi-cog" title="Settings" rounded="lg" class="mb-1" />
        <v-list-item to="/audit-logs" prepend-icon="mdi-history" title="Audit Logs" rounded="lg" class="mb-1" />
      </v-list>
    </v-navigation-drawer>

    <!-- Main Content -->
    <v-main>
      <v-container fluid class="pa-6">
        <router-view />
      </v-container>
    </v-main>

    <!-- Global Snackbar -->
    <v-snackbar
      v-model="appStore.snackbar.show"
      :color="appStore.snackbar.color"
      timeout="3000"
      location="top right"
    >
      {{ appStore.snackbar.text }}
      <template #actions>
        <v-btn variant="text" @click="appStore.snackbar.show = false">Close</v-btn>
      </template>
    </v-snackbar>
  </div>
</template>

<script setup>
import { useAuthStore } from '@/stores/auth'
import { useAppStore } from '@/stores/app'

const authStore = useAuthStore()
const appStore = useAppStore()

const navItems = [
  { to: '/', icon: 'mdi-view-dashboard', title: 'Dashboard' },
  { to: '/approvals', icon: 'mdi-check-decagram', title: 'Pending Approvals' },
  { to: '/partners', icon: 'mdi-account-group', title: 'Partners' },
  { to: '/assets', icon: 'mdi-package-variant-closed', title: 'Assets' },
  { to: '/inventory', icon: 'mdi-warehouse', title: 'Inventory' },
  { to: '/customers', icon: 'mdi-account-multiple', title: 'Customers' },
  { to: '/orders', icon: 'mdi-clipboard-list', title: 'Orders' },
  { to: '/invoices', icon: 'mdi-receipt-text', title: 'Invoices' },
  { to: '/payments', icon: 'mdi-cash-multiple', title: 'Payments' },
  { to: '/expenses', icon: 'mdi-cash-minus', title: 'Expenses' },
]

const reportItems = [
  { to: '/reports/profit', icon: 'mdi-chart-line', title: 'Profit Report' },
  { to: '/reports/labour', icon: 'mdi-account-hard-hat', title: 'Labour Report' },
]
</script>
