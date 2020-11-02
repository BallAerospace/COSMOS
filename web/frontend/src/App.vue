<template>
  <v-app id="app">
    <!-- Sizes your content based upon application components -->
    <v-main>
      <!-- Provides the application the proper gutter -->
      <v-container fluid>
        <router-view />
      </v-container>
    </v-main>
    <AppFooter app />
  </v-app>
</template>

<script>
import AppFooter from '@/AppFooter'

export default {
  components: {
    AppFooter,
  },
}
</script>

<style></style>
