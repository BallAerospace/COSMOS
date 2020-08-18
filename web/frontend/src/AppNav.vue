<template>
  <v-card app>
    <v-navigation-drawer v-model="drawer" app>
      <v-list>
        <v-list-item two-line>
          <v-list-item-icon>
            <img src="/img/logo.png" alt="COSMOS" />
          </v-list-item-icon>
          <v-list-item-content>
            <v-list-item-title>COSMOS</v-list-item-title>
            <v-list-item-subtitle>Enterprise Edition</v-list-item-subtitle>
          </v-list-item-content>
        </v-list-item>

        <v-divider></v-divider>
        <v-list-item
          v-for="app in appNav"
          :key="app.label"
          :to="{ name: app.name }"
        >
          <v-list-item-icon>
            <v-icon>{{ app.icon }}</v-icon>
          </v-list-item-icon>

          <v-list-item-content>
            <v-list-item-title>{{ app.label }}</v-list-item-title>
          </v-list-item-content>
        </v-list-item>
      </v-list>

      <template v-slot:append>
        <div class="pa-2">
          <v-btn block small rounded color="primary" to="admin">Admin</v-btn>
        </div>
      </template>
    </v-navigation-drawer>

    <v-app-bar app color="tertiary darken-3">
      <v-app-bar-nav-icon @click="drawer = !drawer"></v-app-bar-nav-icon>
      <v-menu offset-y v-for="(menu, i) in menus" :key="i">
        <template v-slot:activator="{ on }">
          <v-btn icon v-on="on">{{ menu.label }}</v-btn>
        </template>
        <v-list>
          <!-- The radio-group is necessary in case the application wants radio buttons -->
          <v-radio-group
            :value="menu.radioGroup"
            hide-details
            dense
            class="ma-0 pa-0"
          >
            <template v-for="(option, j) in menu.items">
              <v-divider v-if="option.divider" :key="j"></v-divider>
              <v-list-item v-else :key="j">
                <v-list-item-action v-if="option.radio" @click="option.command">
                  <v-radio
                    color="secondary"
                    :label="option.label"
                    :value="option.label"
                  ></v-radio>
                </v-list-item-action>
                <v-list-item-action
                  v-if="option.checkbox"
                  @click="option.command"
                >
                  <v-checkbox
                    color="secondary"
                    :label="option.label"
                  ></v-checkbox>
                </v-list-item-action>
                <v-list-item-icon v-if="option.icon">
                  <v-icon v-text="option.icon"></v-icon>
                </v-list-item-icon>
                <v-list-item-title
                  v-if="!option.radio && !option.checkbox"
                  @click="option.command"
                  style="cursor: pointer"
                  >{{ option.label }}</v-list-item-title
                >
              </v-list-item>
            </template>
          </v-radio-group>
        </v-list>
      </v-menu>
      <v-spacer />
      <v-toolbar-title>{{ $route.meta.title }}</v-toolbar-title>
      <v-spacer />
      <rux-clock />
    </v-app-bar>
  </v-card>
</template>

<script>
import '@astrouxds/rux-clock'
import '@astrouxds/rux-global-status-bar'

export default {
  props: {
    menus: {
      type: Array,
      default: () => []
    }
  },
  data() {
    return {
      drawer: true,
      appNav: []
    }
  },
  created() {
    this.$router.options.routes.forEach(route => {
      if (route.meta && route.meta.icon) {
        this.appNav.push({
          label: route.meta.title,
          icon: route.meta.icon,
          name: route.name
        })
      }
    })
  }
}
</script>

<style scoped>
.v-list >>> .v-label {
  margin-left: 5px !important;
}
.theme--dark.v-navigation-drawer {
  background-color: var(--v-primary-darken2);
}
</style>
