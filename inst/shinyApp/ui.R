ui <- dashboardPage(
    title = "GenomicScores",
    dashboardHeader(
        title = "GenomicScores",
        tags$li(tags$img(src = 'GenomicScores.png',
                         height = "50vh", width = "50vw"),
                class = "dropdown"),
        titleWidth = 320
    ),
    dashboardSidebar(
        tags$head(
            tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),
            uiOutput("css.apkgs")
        ),
        width = 320,
        selectInput("organism", "Select an Organism",
                    choices = c("All" = "All", unique(options$Organism)),
                    selected = "All"),
        selectInput("category", "Select a Category",
                    choices = c("All" = "All", unique(options$Category)),
                    selected = "All"),
        tags$div(id="cssref", 
                 selectInput("annotPackage", "Select an Annotation Package",
                             choices = NULL)),
        uiOutput("pop"),
        radioButtons("webOrBed", "Input genomic coordinates",
                     choices = list("Manually" = "web", "Uploading BED file" = "bed")),
        uiOutput("webOptions"),
        fileInput("upload", "Upload your Bed format file"),
        splitLayout(
            actionButton("run", "Run", icon = icon("cloud-upload-alt")),
            actionButton("quit", "Quit")
        )
    ),
    dashboardBody(
        shinyjs::useShinyjs(),
        fluidRow(
            tabBox(
                width = 12,
                tabPanel("GScore",
                         fluidRow(id="info",
                                  column(6,
                                         withLoader(verbatimTextOutput("annotPackageInfo"))
                                  ),
                                  column(6,
                                         withLoader(verbatimTextOutput("citation"))
                                  )
                         ),
                         shinycustomloader::withLoader(DT::dataTableOutput("printGs")),
                         uiOutput("down_btn")
                ),
                tabPanel("About",
                         includeMarkdown("about.md")),
                tabPanel("Session Info",
                         verbatimTextOutput("sessionInfo"))
            )
        ),
        # tabsetPanel(type="tabs",
        #             tabPanel("GScore",
        #                      fluidRow(id="info",
        #                               column(6,
        #                                      shinycustomloader::withLoader(verbatimTextOutput("annotPackageInfo"))
        #                               ),
        #                               column(6,
        #                                      shinycustomloader::withLoader(verbatimTextOutput("citation"))
        #                               )
        #                      ),
        #                      shinycustomloader::withLoader(DT::dataTableOutput("printGs")),
        #                      uiOutput("down_btn")
        #             ),
        #             tabPanel("About",
        #                      includeMarkdown("about.md")),
        #             tabPanel("Session Info",
        #                      verbatimTextOutput("sessionInfo"))),
        width = 9
    )
)

