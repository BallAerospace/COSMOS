<template>
  <v-footer id="footer" app color="tertiary darken-3">
    <img src="/img/logo.png" alt="COSMOS" width="20" />
    <span class="footer-text" style="margin-left: 5px">COSMOS &copy; 2020</span>
    <v-spacer />
    <v-btn color="primary" small rounded @click="toggleTheme"
      >Toggle Theme</v-btn
    >
  </v-footer>
</template>

<script>
export default {
  methods: {
    toggleTheme() {
      this.$vuetify.theme.dark = !this.$vuetify.theme.dark
    }
  }
}
</script>

<style scoped>
#footer {
  z-index: 1000; /* On TOP! */
}
</style>
