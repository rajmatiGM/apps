options(rgl.useNULL=TRUE)
library(shiny)
library(animation)
library(Cairo)
library(pitchRx)
library(shinyRGL)

valid <- function(input, default) { 
  if (is.null(input)) return(FALSE)
  if (input == default) return (FALSE)
  return(TRUE)
} #used for repeated checking of whether "valid" input exists


shinyServer(function(input, output) {
  
  getSample <- reactive({
    data(pitches, package = "pitchRx")
    get('pitches')
  })
  
  getLocal <- reactive({
    if (!is.null(input$file)) {
      path <- input$file$datapath 
      read.csv(path)
    } else NULL
  })
  
  getData <- reactive({
    if (input$dataSource == "local") {
      data <- getLocal()
    } else {
      data <- getSample()
    }
  })
  
  getNames <- reactive({
    data <- getData()
    vars <- names(data)
    names(vars) <- vars
  })
  
  output$pointColor <- renderUI({
    n <- getNames()
    selectInput("pointColor", "Choose a 'color' variable:", 
                choices=c("pitch_types"="pitch_types", "None"="None", n))
  })
  
  output$denVar1 <- renderUI({
    if (input$geom %in% c("hex", "tile", "bin")){
      n <- getNames()
      selectInput("denVar1", "Choose a variable:", choices=c("None"="None", n))
    } else NULL
  })
  
  output$denVar2 <- renderUI({
    if (input$geom %in% c("hex", "tile", "bin")){
      n <- getNames()
      selectInput("denVar2", "Choose a variable:", choices=c("None"="None", n))
    } else NULL
  })
  
  output$vals1 <- renderUI({
    if (!is.null(input$denVar1)) {
      if (input$denVar1 != "None") {
        data <- getData()
        vals <- sort(unique(data[,input$denVar1]))
        checkboxGroupInput("vals1", "Select value(s) of this variable:", 
                           choices  = vals, selected = vals[[1]])
      } else NULL
    } else NULL
  })
  
  output$vals2 <- renderUI({
    if (!is.null(input$denVar1)) {
      if (input$denVar2 != "None") {
        data <- getData()
        vals <- sort(unique(data[,input$denVar2]))
        checkboxGroupInput("vals2", "Select value(s) of this variable:", 
                           choices  = vals, selected = vals[[1]])
      } else NULL
    } else NULL
  })
  
  output$pitcher <- renderUI({
    dat <- getData()
    n <- grep("pitcher_name", names(dat))
    if (length(n) > 0) {
      nms <- unique(dat[,n])
      selectInput("pitcher", "Select pitcher of interest", choices = nms)
    } else NULL
  })
  
  output$myWebGL <- renderWebGL({
    dat <- getData()
    #for subset to work, must upload column named "pitcher_name"
    if (!is.null(input$pitcher)) dat <- subset(dat, pitcher_name == input$pitcher)
    if (input$avgby){
      interactiveFX(dat, avg.by="pitch_types", alpha=input$alpha, interval=input$interval, spheres=input$spheres)
    } else {
      interactiveFX(dat, alpha=input$alpha, interval=input$interval, spheres=input$spheres)
    }
  })
  
  
  plotFX <- reactive({
    data <- getData()
    #Build facetting call
    facet1 <- input$facet1
    facet2 <- input$facet2
    if (facet1 == "Enter my own") facet1 <- input$facet1custom
    if (facet2 == "Enter my own") facet2 <- input$facet2custom
    if (facet1 == "No facet" & facet2 == "No facet") 
      facet_layer <- list()
    if (facet1 != "No facet" & facet2 == "No facet") {
      facet_layer <- call("facet_grid", paste(".~", facet1, sep=""))
    }
    if (facet1 == "No facet" & facet2 != "No facet") {  
      facet_layer <- call("facet_grid", paste(facet2, "~.", sep=""))
    }
    if (facet1 != "No facet" & facet2 != "No facet") {
      facet_layer <- call("facet_grid", paste(facet2, "~", facet1, sep=""))
    }
    if (input$coord.equal) {
      coord_equal <- coord_equal()
    } else coord_equal <- NULL
    
    if (input$tabs == "animate") {
      oopt <- ani.options(interval = 0.01, ani.dev = CairoPNG, 
                          title = "My pitchRx Animation", 
                          description = "Generated from <a href='http://cpsievert.github.com/home.html'>Carson Sievert</a>'s PITCHf/x <a href='https://gist.github.com/4440099'>visualization tool</a>")
      ani.start()
      print(animateFX(data, point.size=input$point_size, 
                      point.alpha=input$point_alpha, 
                      layer=list(facet_layer, coord_equal), parent=TRUE))
      ani.stop()
      ani.options(oopt)
    }
    #Set binwidths for hex and bins
    #contours require special handling within each geometry
    binwidths <- NULL
    if (input$geom == "hex") {
      binwidths <- c(input$hex_xbin, input$hex_ybin)
      contours <- input$hex_contour
      a <- input$hex_adjust
    }
    if (input$geom == "bin") {
      binwidths <- c(input$bin_xbin, input$bin_ybin)
      contours <- input$bin_contour
      a <- input$bin_adjust
    }
    if (input$geom == "point") {
      contours <- input$point_contour
      a <- input$point_adjust
    }
    if (input$geom == "tile") {
      contours <- input$tile_contour
      a <- input$tile_adjust
    }
    if (input$tabs == "2D Scatterplot") {
      den1 <- list()
      den2 <- list()
      if (valid(input$denVar1, "None") && !is.null(input$vals1)) {
        den1 <- list(input$vals1)
        names(den1) <- input$denVar1
      }
      if (valid(input$denVar2, "None") && !is.null(input$vals1)) {
        den2 <- list(input$vals2)
        names(den2) <- input$denVar2
      }
      if (!is.null(input$pointColor)) {
        pointColor <- input$pointColor
      } else pointColor <- "pitch_types"
      print(strikeFX(data, geom=input$geom, point.size=input$point_size, 
                     point.alpha=input$point_alpha, color=pointColor, density1=den1,
                     density2=den2, layer=list(facet_layer, coord_equal), contour=contours, 
                     adjust=a, limitz=c(input$xmin, input$xmax, input$ymin, input$ymax),
                     binwidth=binwidths, parent=TRUE))
    }
  })
  
  output$staticPlot <- renderPlot({
    print(plotFX())
  })
  
  output$downloadPlot <- downloadHandler(
    filename <- function() {
      pre <- paste("pitchRx", as.POSIXct(Sys.Date()), sep="-")
      paste(pre, ".png", sep="")
    },
    content <- function(file) {
      png(file) 
      print(plotFX())
      dev.off()
    },
    contentType = 'image/png'
  )
  
})