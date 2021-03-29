const _severities = [
  // order of severities from highest to lowest
  'critical',
  'serious',
  'caution',
  'normal',
  'standby',
  'off',
]

const _getSeverityIndeces = function (severities) {
  return severities.map((severity) => _severities.indexOf(severity.toLowerCase()))
}

const highestSeverity = function (severities) {
  const indeces = _getSeverityIndeces(severities)
  const index = Math.min(...indeces)
  return _severities[index]
}

const lowestSeverity = function (severities) {
  const indeces = _getSeverityIndeces(severities)
  const index = Math.max(...indeces)
  return _severities[index]
}

const orderBySeverity = function (objects, severityGetter = (x) => x.severity) {
  return objects.sort((a, b) => {
    return _severities.indexOf(severityGetter(a)) - _severities.indexOf(severityGetter(b))
  })
}

const groupBySeverity = function (objects, severityGetter = (x) => x.severity) {
  return objects.reduce((groups, obj) => {
    const severity = severityGetter(obj)
    groups[severity] ||= []
    groups[severity].push(obj)
    return groups
  }, {})
}

export { highestSeverity, lowestSeverity, orderBySeverity, groupBySeverity }
