############################################################
#This is the Shiny file for the Basic Bacteria App
#written and maintained by Andreas Handel (ahandel@uga.edu)
#last updated 12/6/2017
############################################################

#the server-side function with the main functionality
#this function is wrapped inside the shiny server function below to allow return to main menu when window is closed
refresh <- function(input, output)
  {

  result <- reactive({
    input$submitBtn

  # Read all the input values from the UI
    B0 = isolate(input$B0);
    I0 = isolate(input$I0);
    b = isolate(input$b);
    Bmax = 10^isolate(input$Bmax);
    dB = isolate(input$dB);
    k = 10^isolate(input$k);
    g = isolate(input$g);
    r = 10^isolate(input$r);
    dI = isolate(input$dI);
    tmax = isolate(input$tmax);
    dt = isolate(input$dt)
    models = as.numeric(isolate(input$models))
    plotscale = isolate(input$plotscale)

    #save all results to a list for processing plots and text
    listlength = 1; #here we do all simulations in the same figure
    result = vector("list", listlength) #create empty list of right size for results

    #shows a 'running simulation' message
    withProgress(message = 'Running Simulation', value = 0,
    {

    # Call the ODE solver with the given parameters
    if (models == 1 | models == 3)
    {
      result_ode <- simulate_basicbacteria(B0 = B0, I0 = I0, tmax = tmax, g=g, Bmax=Bmax, dB=dB, k=k, r=r, dI=dI)
      colnames(result_ode) = c('xvals','Bc','Ic')
      dat_ode = tidyr::gather(as.data.frame(result_ode), -xvals, value = "yvals", key = "varnames")
      dat_ode$setting = 'ode'
    }

    # Call the discrete model with the given parameters
    if (models == 2 | models == 3)
    {
      result_discrete <- simulate_basicbacteria_discrete(B0 = B0, I0 = I0, tmax = tmax, g=g, Bmax=Bmax, dB=dB, k=k, r=r, dI=dI, dt = dt)
      colnames(result_discrete) = c('xvals','Bd','Id')
      #reformat data to be in the right format for plotting
      #each plot/text output is a list entry with a data frame in form xvals, yvals, extra variables for stratifications for each plot
      dat_disc = tidyr::gather(as.data.frame(result_discrete), -xvals, value = "yvals", key = "varnames")
      dat_disc$setting = 'discrete'
    }

    }) #end the 'with progress' wrapper


    #depending on if user wants only 1 model or both
    if (models == 1) { dat = dat_ode}
    if (models == 2) { dat = dat_disc}
    if (models == 3) { dat = rbind(dat_ode, dat_disc)  }

    #code variable names as factor and level them so they show up right in plot - factor is needed for plotting and text
    mylevels = unique(dat$varnames)
    dat$varnames = factor(dat$varnames, levels = mylevels)

    #data for plots and text
    #each variable listed in the varnames column will be plotted on the y-axis, with its values in yvals
    #each variable listed in varnames will also be processed to produce text
    result[[1]]$dat = dat

    #Meta-information for each plot
    result[[1]]$plottype = "Lineplot"
    result[[1]]$xlab = "Time"
    result[[1]]$ylab = "Numbers"
    result[[1]]$legend = "Compartments"

    result[[1]]$xscale = 'identity'
    result[[1]]$yscale = 'identity'

    if (plotscale == 'x' | plotscale == 'both') { result[[1]]$xscale = 'log10'}
    if (plotscale == 'y' | plotscale == 'both') { result[[1]]$yscale = 'log10'}

    #the following are for text display for each plot
    result[[1]]$maketext = TRUE #if true we want the generate_text function to process data and generate text, if 0 no result processing will occur insinde generate_text
    result[[1]]$showtext = '' #text for each plot can be added here which will be passed through to generate_text and displayed for each plot
    result[[1]]$finaltext = 'Numbers are rounded to 2 significant digits.' #text can be added here which will be passed through to generate_text and displayed for each plot

  return(result)
  })

  #functions below take result saved in reactive expression result and produce output
  #to produce figures, the function generate_plot is used
  #function generate_text produces text
  #data needs to be in a specific structure for processing
  #see information for those functions to learn how data needs to look like
  #output (plots, text) is stored in reactive variable 'output'

  output$plot  <- renderPlot({
    input$submitBtn
    res=isolate(result()) #list of all results that are to be turned into plots
    generate_plots(res) #create plots with a non-reactive function
  }, width = 'auto', height = 'auto'
  ) #finish render-plot statement

  output$text <- renderText({
    input$submitBtn
    res=isolate(result()) #list of all results that are to be turned into plots
    generate_text(res) #create text for display with a non-reactive function
  })


} #ends the 'refresh' shiny server function that runs the simulation and returns output

#main shiny server function
server <- function(input, output, session) {

  # Waits for the Exit Button to be pressed to stop the app and return to main menu
  observeEvent(input$exitBtn, {
    input$exitBtn
    stopApp(returnValue = 0)
  })

  # This function is called to refresh the content of the Shiny App
  refresh(input, output)

  # Event handler to listen for the webpage and see when it closes.
  # Right after the window is closed, it will stop the app server and the main menu will
  # continue asking for inputs.
  session$onSessionEnded(function(){
    stopApp(returnValue = 0)
  })
} #ends the main shiny server function


#This is the UI part of the shiny App
ui <- fluidPage(
  includeCSS("../styles/dsairm.css"),
  #add header and title
  tags$head( tags$script(src="//cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML", type = 'text/javascript') ),
  tags$head(tags$style(".myrow{vertical-align: bottom;}")),
  div( includeHTML("www/header.html"), align = "center"),
  #specify name of App below, will show up in title
  h1('Basic Bacteria App', align = "center", style = "background-color:#123c66; color:#fff"),

  #section to add buttons
  fluidRow(
    column(6,
           actionButton("submitBtn", "Run Simulation", class="submitbutton")
    ),
    column(6,
           actionButton("exitBtn", "Exit App", class="exitbutton")
    ),
    align = "center"
  ), #end section to add buttons

  tags$hr(),

  ################################
  #Split screen with input on left, output on right
  fluidRow(
    #all the inputs in here
    column(6,
           #################################
           # Inputs section
           h2('Simulation Settings'),
           fluidRow( class = 'myrow',
             column(4,
                    numericInput("B0", "Initial number of bacteria,  B0", min = 0, max = 1000, value = 100, step = 50)
             ),
             column(4,
                    numericInput("I0", "Initial number of immune cells, I0", min = 0, max = 100, value = 10, step = 1)
             ),
             column(4,
                    numericInput("tmax", "Maximum simulation time", min = 10, max = 200, value = 100, step = 10)
             ),
             align = "center"
           ), #close fluidRow structure for input



           fluidRow(class = 'myrow',
             column(4,
                    numericInput("g", "Rate of bacteria growth, g", min = 0, max = 10, value = 1.5, step = 0.1)
             ),
             column(4,
                    numericInput("Bmax", "carrying capacity, Bmax (10^Bmax)", min = 1, max = 10, value = 5, step = 1)
             ),
             column(4,
                    numericInput("dB", "bacteria death rate, dB", min = 0, max = 10, value = 1, step = 0.1)
             ),
             align = "center"
           ), #close fluidRow structure for input

           fluidRow(class = 'myrow',
                    column(4,
                           numericInput("k", "immune response kill rate, k (10^k)", min = -10, max = 2, value = -4, step = 0.5)
                    ),
                    column(4,
                           numericInput("r", "immune respone activation rate, r (10^r)", min = -10, max = 2, value = -4, step = 0.5)
                    ),
                    column(4,
                           numericInput("dI", "Immune response death rate, dI", min = 0, max = 10, value = 2, step = 0.1)
                    ),
                    align = "center"
           ), #close fluidRow structure for input

           fluidRow(class = 'myrow',
                    column(4,
                           numericInput("dt", "Discrete time step, dt", min = 0.001, max = 10, value = 0.1, step = 0.001)
                    ),
                    column(4,
                           selectInput("models", "Models to run:",c("continuous time" = 1, 'discrete time' = 2, 'both' = 3), selected = '1')
                    ),
                    column(4,
                           selectInput("plotscale", "Log-scale for plot:",c("none" = "none", 'x-axis' = "x", 'y-axis' = "y", 'both axes' = "both"), selected = 'none')
                    ),
                    align = "center"
           ) #close fluidRow structure for input


    ), #end sidebar column for inputs

    #all the outcomes here
    column(6,

           #################################
           #Start with results on top
           h2('Simulation Results'),
           plotOutput(outputId = "plot", height = "500px"),
           # PLaceholder for results of type text
           htmlOutput(outputId = "text"),
           tags$hr()

           ) #end main panel column with outcomes
  ), #end layout with side and main panel

  #################################
  #Instructions section at bottom as tabs
  h2('Instructions'),
  #use external function to generate all tabs with instruction content
  do.call(tabsetPanel,generate_instruction_tabs()),
  div(includeHTML("www/footer.html"), align="center", style="font-size:small") #footer

) #end fluidpage function, i.e. the UI part of the app

shinyApp(ui = ui, server = server)
