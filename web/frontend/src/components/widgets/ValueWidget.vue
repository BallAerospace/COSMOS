<template>
  <div>
    <v-text-field
      solo
      dense
      readonly
      single-line
      hide-no-data
      hide-details
      placeholder="Value"
      :value="_value"
      :class="valueClass"
      :style="computedStyle"
      data-test="value"
      @contextmenu="showContextMenu"
    />
    <v-menu
      v-model="contextMenuShown"
      :position-x="x"
      :position-y="y"
      absolute
      offset-y
    >
      <v-list>
        <v-list-item
          v-for="(item, index) in contextMenuOptions"
          :key="index"
          @click.stop="item.action"
        >
          <v-list-item-title>{{ item.title }}</v-list-item-title>
        </v-list-item>
      </v-list>
    </v-menu>

    <DetailsDialog
      :targetName="parameters[0]"
      :packetName="parameters[1]"
      :itemName="parameters[2]"
      v-model="viewDetails"
    />
  </div>
</template>

<script>
import VWidget from './VWidget'
import DetailsDialog from '@/components/DetailsDialog'
export default {
  components: {
    DetailsDialog
  },
  mixins: [VWidget]
}
</script>

<style scoped>
.value >>> div {
  min-height: 24px !important;
  display: flex !important;
  align-items: center !important;
}
.cosmos-green >>> input {
  color: rgb(0, 150, 0);
}
.cosmos-yellow >>> input {
  color: rgb(190, 135, 0);
}
.cosmos-red >>> input {
  color: red;
}
.cosmos-blue >>> input {
  color: rgb(0, 100, 255);
}
.cosmos-purple >>> input {
  color: rgb(200, 0, 200);
}
.cosmos-black >>> input {
  color: black;
}
.cosmos-white >>> input {
  color: white;
}
</style>
