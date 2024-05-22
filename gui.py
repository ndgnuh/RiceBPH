from PyQt6 import QtCore, QtGui, QtWidgets
from PyQt6.QtWidgets import (QApplication, QComboBox, QLabel, QMainWindow,
                             QPushButton)


class SimulationRunner(QtCore.QProcess):
    onStdout = QtCore.pyqtSignal(str)
    onStderr = QtCore.pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self.readyReadStandardOutput.connect(self.handleStdout)
        self.readyReadStandardError.connect(self.handleStderr)

    def handleStdout(self):
        stdout = bytes(self.readAllStandardOutput()).decode("utf-8", "ignore")
        self.onStdout.emit(stdout)

    def handleStderr(self):
        stderr = bytes(self.readAllStandardError()).decode("utf-8", "ignore")
        self.onStderr.emit(stderr)

    def start(
        self,
        map_size,
        flower_width,
        energy_transfer,
        init_num_bphs,
        init_pr_eliminate,
        init_position,
        seed: int = 0,
    ):
        super().start(
            "julia",
            [
                "--project",
                "scripts/exploration.jl",
                "--seed",
                "0",
                "--map-size",
                str(map_size),
                "--flower-width",
                str(flower_width),
                "--energy-transfer",
                str(energy_transfer),
                "--init-num-bphs",
                str(init_num_bphs),
                "--init-pr-eliminate",
                str(init_pr_eliminate),
                "--init-position",
                str(init_position),
            ],
        )


class QFloatInput(QtWidgets.QLineEdit):
    def __init__(self, *args, **kwargs):
        super().__init__()
        self.textEdited.connect(self._removeNonFloat)
        self.setValue(0.0)

    def setValue(self, text):
        self.setText(str(text))

    def value(self):
        return float(self.text())

    def _removeNonFloat(self):
        text = self.text()
        period = True

        def valid(c):
            nonlocal period
            if c == "." and period:
                period = False
                return True
            else:
                return c in "0123456789"

        newText = [c for c in text if valid(c)]
        newText = "".join(newText)
        if text != newText:
            self.setText(newText)


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.simulationStarted = True
        self.proc = SimulationRunner()
        self.setupGui()

    def haltSimulation(self):
        self.proc.kill()

    def runSimulation(self):
        print("Please wait, starting simulation")

        self.proc.start(
            init_position=self.input_init_position.currentText().lower(),
            map_size=self.input_map_size.value(),
            flower_width=self.input_flower_width.value(),
            energy_transfer=self.input_energy_transfer.value(),
            init_num_bphs=self.input_init_num_bphs.value(),
            init_pr_eliminate=self.input_init_pr_eliminate.value(),
            seed=0,
        )

    def setupGui(self):
        self.setWindowTitle("RiceBPH GUI")

        container = QtWidgets.QWidget()
        form = QtWidgets.QFormLayout()
        container.setLayout(form)
        self.setCentralWidget(container)

        self.input_map_size = QtWidgets.QSpinBox()
        self.input_map_size.setMaximum(10000)
        self.input_map_size.setMinimum(50)
        self.input_map_size.setValue(125)
        form.addRow(QLabel("Map size"), self.input_map_size)

        self.input_flower_width = QtWidgets.QSpinBox()
        self.input_flower_width.setMinimum(0)
        form.addRow(QLabel("Flower width"), self.input_flower_width)

        self.input_init_num_bphs = QtWidgets.QSpinBox()
        self.input_init_num_bphs.setMinimum(0)
        self.input_init_num_bphs.setMaximum(1000)
        self.input_init_num_bphs.setValue(200)
        form.addRow(QLabel("Initial number of BPHs"), self.input_init_num_bphs)

        self.input_init_position = QtWidgets.QComboBox()
        self.input_init_position.addItems(["Corner", "Border", "Random"])
        form.addRow(QLabel("Initial position"), self.input_init_position)

        self.input_energy_transfer = QFloatInput()
        self.input_energy_transfer.setValue(0.032)
        form.addRow(QLabel("Energy transfer"), self.input_energy_transfer)

        self.input_init_pr_eliminate = QFloatInput()
        form.addRow(QLabel("Elimination probability"), self.input_init_pr_eliminate)

        self.button_run = QPushButton("Run")
        self.button_reset = QPushButton("Reset")
        form.addRow(QLabel("Actions"), self.button_run)
        form.addRow(QLabel(""), self.button_reset)

        self.button_run.clicked.connect(self.runSimulation)
        self.button_reset.clicked.connect(self.haltSimulation)

        # Stdout/in panel
        termStdout = QtWidgets.QPlainTextEdit()
        termStdout.setReadOnly(True)
        termStderr = QtWidgets.QPlainTextEdit()
        termStderr.setReadOnly(True)
        form.addRow(termStderr, termStdout)

        # Status bar
        statusBar = QtWidgets.QStatusBar()
        self.setStatusBar(statusBar)

        def runState():
            statusBar.showMessage("Running simulation...")
            self.button_run.setEnabled(False)
            self.button_reset.setEnabled(True)

        def stopState():
            statusBar.showMessage("Simulation stopped.")
            self.button_run.setEnabled(True)
            self.button_reset.setEnabled(True)

        self.proc.started.connect(runState)
        self.proc.finished.connect(stopState)
        self.proc.onStderr.connect(termStderr.appendPlainText)
        self.proc.onStdout.connect(termStdout.appendPlainText)


if __name__ == "__main__":
    app = QApplication([])
    win = MainWindow()
    win.show()
    app.exec()
