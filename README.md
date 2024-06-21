# Plasma-6-power-usage-widget

Sadly, https://github.com/atul-g/plasma-power-monitor widget never got updated to Plasma 6. 
With mighty help of different LLMs, I made a widget inspired by it. It doesn't share any code with it. I just liked the idea and what it did.
Plasma's System Monitor widget and one of its sensors have similar feature but it refreshes every 10 seconds or so, and it can't be changed to smaller interval. 

The widget has no configuration options but you can edit /contents/ui/main.qml file to change font size, for example. 
The widget displays power consumption or charging rate expressed in Watts. If power usage goes above 12W, the colour of the font changes to red.
Power usage is expressed as negative value. When battery is charging, a bolt symbol is displayed. When battery is fully charged, just the bolt symbol shows. 
