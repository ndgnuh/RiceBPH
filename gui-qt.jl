using PyCall

@info "Loading RiceBPH package"
using Agents
using RiceBPH

@info "Loading Qt packages"
const QtWidgets = pyimport("PyQt6.QtWidgets")
const QtCore = pyimport("PyQt6.QtCore")
const QLabel = QtWidgets.QLabel
const QPushButton = QtWidgets.QPushButton

function QFloatInput(args...; kwargs...)
   self = QtWidgets.QLineEdit()

   # Set value
   self.setValue = function (value)
      self.setText(string(value))
   end

   # Get value
   self.value = function ()
      return parse(Float32, self.text())
   end

   self._sanitize = function (_)
      text = self.text()
      period = Ref(true)
      function valid(c)
         if c == '.' && period[]
            period[] = false
            return true
         else
            return c in "0123456789"
         end
      end
      next_text = join([c for c in collect(text) if valid(c)], "")
      if text != next_text
         self.setText(next_text)
      end
   end

   # Sanitize
   self.textEdited.connect(self._sanitize)
   self.setValue(0.0)
   return self
end

function main()
   # Initialize
   app = QtWidgets.QApplication([])
   win = QtWidgets.QMainWindow()

   win.setWindowTitle("RiceBPH GUI")
   win.setStatusBar(QtWidgets.QStatusBar())

   container = QtWidgets.QWidget()
   form = QtWidgets.QFormLayout()
   container.setLayout(form)
   win.setCentralWidget(container)

   win.input_map_size = QtWidgets.QSpinBox()
   win.input_map_size.setMaximum(10000)
   win.input_map_size.setMinimum(50)
   win.input_map_size.setValue(125)
   form.addRow(QLabel("Map size"), win.input_map_size)

   win.input_flower_width = QtWidgets.QSpinBox()
   win.input_flower_width.setMinimum(0)
   form.addRow(QLabel("Flower width"), win.input_flower_width)

   win.input_init_num_bphs = QtWidgets.QSpinBox()
   win.input_init_num_bphs.setMinimum(0)
   win.input_init_num_bphs.setMaximum(1000)
   win.input_init_num_bphs.setValue(200)
   form.addRow(QLabel("Initial number of BPHs"), win.input_init_num_bphs)

   win.input_init_position = QtWidgets.QComboBox()
   win.input_init_position.addItems(["Corner", "Border", "Random"])
   form.addRow(QLabel("Initial position"), win.input_init_position)

   win.input_energy_transfer = QFloatInput()
   win.input_energy_transfer.setValue(0.032)
   form.addRow(QLabel("Energy transfer"), win.input_energy_transfer)

   win.input_init_pr_eliminate = QFloatInput()
   form.addRow(QLabel("Elimination probability"), win.input_init_pr_eliminate)

   win.input_seed = QtWidgets.QSpinBox()
   win.input_seed.setMaximum(1_000_000)
   win.input_seed.setMinimum(0)
   win.input_seed.setValue(0)
   form.addRow(QLabel("Random seed"), win.input_seed)

   win.button_run = QPushButton("Run")
   form.addRow(win.button_run)

   # Status bar is bugged
   win.status = QLabel()
   form.addRow(win.status)

   win.button_run.clicked.connect() do (_::Bool)
      @info "Initializing simulation"
      win.status.setText("Please wait while loading the simulation")

      # Init model
      init_position_str = lowercase(win.input_init_position.currentText())
      init_position = convert(RiceBPH.Models.InitPosition, init_position_str)
      model = RiceBPH.Models.init_model(;
         init_position = init_position,
         map_size = win.input_map_size.value(),
         flower_width = win.input_flower_width.value(),
         energy_transfer = win.input_energy_transfer.value(),
         init_num_bphs = win.input_init_num_bphs.value(),
         init_pr_eliminate = win.input_init_pr_eliminate.value(),
         seed = win.input_seed.value(),
      )

      # Init exploration
      mdata = RiceBPH.Models.MDATA_EXPL
      fig, _ = abmexploration(
         model;
         mdata,
         RiceBPH.Models.agent_step!,
         RiceBPH.Models.model_step!,
         RiceBPH.Visualisations.ac,
         RiceBPH.Visualisations.heatkwargs,
         RiceBPH.Visualisations.heatarray,
      )

      # Done
      scene = display(fig)
      win.status.setText("Simulation initialized")
      wait(scene)

      win.status.setText("Simulation terminated")
   end

   # Stdout/in panel
   #= termStdout = QtWidgets.QPlainTextEdit() =#
   #= termStdout.setReadOnly(true) =#
   #= termStderr = QtWidgets.QPlainTextEdit() =#
   #= termStderr.setReadOnly(true) =#
   #= form.addRow(termStderr, termStdout) =#

   # Run
   win.show()
   app.exec()
end

main()
