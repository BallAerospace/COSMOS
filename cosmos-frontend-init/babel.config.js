module.exports = {
  presets: ['@vue/app'],
  plugins: [
    [
      'babel-plugin-istanbul',
      {
        extension: ['.js', '.vue'],
      },
    ],
  ],
}
