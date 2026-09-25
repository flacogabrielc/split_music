flacogabrielc@flacogabrielc-GWTN141-10:~$ mkdir -p ~/proyectos/spleeter
cd ~/proyectos/spleeter

flacogabrielc@flacogabrielc-GWTN141-10:~/proyectos/spleeter$ python3 -m venv venv

source venv/bin/activate

demucs -n htdemucs_6s --two-stems=guitar "cancion.mp3"
demucs -n htdemucs_6s --two-stems=guitar "Down by the Seaside.mp3"

/home/flacogabrielc/proyectos/spleeter/mp3/Down by the Seaside


'Down by the Seaside.mp3'

/home/flacogabrielc/proyectos/spleeter
(venv) flacogabrielc@flacogabrielc-GWTN141-10:~/proyectos/spleeter$ deactivate

flacogabrielc@flacogabrielc-GWTN141-10:~/proyectos/spleeter$ source venv/bin/activate


bash
demucs -n htdemucs_6s --two-stems=guitar "cancion.mp3"
La salida que obtendrías sería:

guitar.wav (la guitarra aislada)

no_guitar.wav (todo lo demás: batería, bajo, voz, piano y "other" mezclados)

es decir, con --two-stems=guitar:

Demucs separa los 6 stems (drums, bass, other, vocals, guitar, piano).

Guarda guitar.wav como archivo independiente.

Suma los otros 5 en no_guitar.wav.


Quieres todos los stems por separado para mezclar en DAW	
demucs -n htdemucs_6s cancion.mp3

Quieres ahorrar disco y solo guardar la guitarra	
demucs -n htdemucs_6s --stems guitar cancion.mp3

demucs "cancion.mp3"
Salida: separated/htdemucs/cancion/ con vocals.wav, drums.wav, bass.wav y other.wav.

bash
demucs -n htdemucs_6s "cancion.mp3"
Salida: separated/htdemucs_6s/cancion/ con guitar.wav y piano.wav adicionales.

Nota: Este modelo es experimental. La calidad de la guitarra es aceptable, pero la del piano suele tener más artefactos.

Si solo te interesan ciertas pistas, puedes pedirlas directamente para ahorrar tiempo y espacio.

bash
# Solo batería y bajo del modelo de 4 pistas
demucs --stems drums bass "cancion.mp3"

# Solo guitarra del modelo de 6 pistas
demucs -n htdemucs_6s --stems guitar "cancion.mp3"

Para obtener solo voz e instrumental (o cualquier otra combinación binaria), usas --two-stems.

bash
# Obtener voz por un lado y todo lo demás por otro
demucs --two-stems=vocals "cancion.mp3"

rescale (por defecto): Reescala el volumen de los stems para evitar saturación. Esto puede alterar el volumen relativo entre pistas.

bash
demucs --clip-mode rescale "cancion.mp3"
clamp: Recorta la señal si satura (hard clipping). Preserva mejor las proporciones de volumen originales, pero puede introducir distorsión audible.

bash
demucs --clip-mode clamp "cancion.mp3"
none: No aplica ningún procesamiento de clipping. Puede saturar si la señal es muy fuerte.

bash
demucs --clip-mode none "cancion.mp3"
6. Combinación de opciones: ejemplos avanzados
Puedes combinar las opciones anteriores según lo que necesites.

bash
# Modelo de 6 pistas, solo guitarra, con modo clamp para preservar volumen
demucs -n htdemucs_6s --stems guitar --clip-mode clamp "cancion.mp3"

# Modelo de 4 pistas, solo batería y bajo, salida en MP3
demucs --stems drums bass --mp3 "cancion.mp3"

# Modo karaoke con modelo fine-tuned (mejor calidad, más lento)
demucs -n htdemucs_ft --two-stems=vocals "cancion.mp3"

Orden de las pistas: Cuando uses --stems, el orden de los argumentos debe coincidir con los nombres de las pistas del modelo (drums, bass, other, vocals para 4 pistas; añade guitar y piano para 6).

Modelos disponibles: Puedes listar todos los modelos preentrenados con demucs --list-models. Los más comunes son htdemucs (4 pistas, por defecto), htdemucs_ft (fine-tuned, mejor calidad pero 4 veces más lento) y htdemucs_6s (6 pistas, experimental).

Recuerda: Siempre ejecuta estos comandos dentro de tu entorno virtual (venv) activado para que todo funcione correctamente.




