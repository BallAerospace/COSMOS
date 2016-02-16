### Table of Contents

<span>[Definitions](#definitions)</span><br/>
<br/>
<span>[Telemetry Viewer Configuration](#telemetry-viewer-configuration)</span><br/>
<br/>
<span>[Telemetry Screen Definition Files](#telemetry-screen-definition-files)</span><br/>
<br/>
<span>[Keywords:](#keywords:)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [SCREEN](#screen)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [END](#end)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [GLOBAL_SETTING](#globalsetting)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [GLOBAL_SUBSETTING](#globalsubsetting)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [SETTING](#setting)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [SUBSETTING](#subsetting)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [NAMED_WIDGET](#namedwidget)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [WIDGETNAME](#widgetname)<br/>
<br/>
<span>[Example File](#example-file)</span><br/>
<br/>
<span>[Telemetry Viewer Settings Files](#telemetry-viewer-settings-files)</span><br/>
<br/>
<span>[Keywords:](#keywords:)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [AUTO_TARGETS](#autotargets)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [AUTO_TARGET](#autotarget)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [NEW_COLUMN](#newcolumn)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [TARGET](#target)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [SCREEN](#screen)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [SHOW_ON_STARTUP](#showonstartup)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [ADD_SHOW_ON_STARTUP](#addshowonstartup)<br/>
<br/>
<span>[Example File](#example-file)</span><br/>
<br/>
<span>[Widget Descriptions](#widget-descriptions)</span><br/>
<br/>
<span>[Layout Widgets](#layout-widgets)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [VERTICAL](#vertical)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [VERTICALBOX](#verticalbox)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [HORIZONTAL](#horizontal)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [HORIZONTALBOX](#horizontalbox)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [MATRIXBYCOLUMNS](#matrixbycolumns)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [SCROLLWINDOW](#scrollwindow)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [TABBOOK](#tabbook)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [TABITEM](#tabitem)<br/>
<br/>
<span>[Decoration Widgets](#decoration-widgets)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [LABEL](#label)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [HORIZONTALLINE](#horizontalline)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [SECTIONHEADER](#sectionheader)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [TITLE](#title)<br/>
<br/>
<span>[Telemetry widgets](#telemetry-widgets)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [ARRAY](#array)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [BLOCK](#block)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [FORMATFONTVALUE](#formatfontvalue)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [FORMATVALUE](#formatvalue)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [LABELPROGRESSBAR](#labelprogressbar)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [LABELTRENDLIMITSBAR](#labeltrendlimitsbar)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [LABELVALUE](#labelvalue)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [LABELVALUEDESC](#labelvaluedesc)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [LABELVALUELIMITSBAR](#labelvaluelimitsbar)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [LABELVALUELIMITSCOLUMN](#labelvaluelimitscolumn)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [LABELVALUERANGEBAR](#labelvaluerangebar)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [LABELVALUERANGECOLUMN](#labelvaluerangecolumn)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [LIMITSBAR](#limitsbar)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [LIMITSCOLUMN](#limitscolumn)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [LIMITSCOLOR](#limitscolor)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [VALUELIMITSBAR](#valuelimitsbar)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [VALUELIMITSCOLUMN](#valuelimitscolumn)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [VALUERANGEBAR](#valuerangebar)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [VALUERANGECOLUMN](#valuerangecolumn)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [LINEGRAPH](#linegraph)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [PROGRESSBAR](#progressbar)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [RANGEBAR](#rangebar)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [RANGECOLUMN](#rangecolumn)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [TEXTBOX](#textbox)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [TIMEGRAPH](#timegraph)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [TRENDBAR](#trendbar)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [TRENDLIMITSBAR](#trendlimitsbar)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [VALUE](#value)<br/>
<br/>
<span>[Interactive Widgets](#interactive-widgets)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [BUTTON](#button)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [CHECKBUTTON](#checkbutton)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [COMBOBOX](#combobox)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [RADIOBUTTON](#radiobutton)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [TEXTFIELD](#textfield)<br/>
<br/>
<span>[Canvas Widgets](#canvas-widgets)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [CANVAS](#canvas)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [CANVASLABEL](#canvaslabel)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [CANVASLABELVALUE](#canvaslabelvalue)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [CANVASIMAGE](#canvasimage)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [CANVASIMAGEVALUE](#canvasimagevalue)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [CANVASLINE](#canvasline)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [CANVASLINEVALUE](#canvaslinevalue)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [CANVASDOT](#canvasdot)<br/>
<br/>
<span>[Widget Settings](#widget-settings)</span><br/>
<br/>
<span>[Common Settings](#common-settings)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [BACKCOLOR](#backcolor)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [TEXTCOLOR](#textcolor)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [WIDTH](#width)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [HEIGHT](#height)<br/>
<br/>
<span>[Widget-Specific Settings](#widget-specific-settings)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [BORDERCOLOR](#bordercolor)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [COLORBLIND](#colorblind)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [ENABLE_AGING](#enableaging)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [GRAY_RATE / GREY_RATE](#grayrate-/-greyrate)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [GRAY_TOLERANCE / GREY_TOLERANCE](#graytolerance-/-greytolerance)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [MIN_GRAY / MIN_GREY](#mingray-/-mingrey)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [TREND_SECONDS](#trendseconds)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [VALUE_EQ](#valueeq)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [VALUE_GT](#valuegt)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [VALUE_GTEQ](#valuegteq)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [VALUE_LT](#valuelt)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [VALUE_LTEQ](#valuelteq)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [TLM_AND](#tlmand)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [TLM_OR](#tlmor)<br/>
