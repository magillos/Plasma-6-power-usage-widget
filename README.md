# Plasma-6-power-usage-widget

Sadly, https://github.com/atul-g/plasma-power-monitor widget never got updated to Plasma 6. 
With mighty help of different LLMs, I made a widget inspired by it. It doesn't share any code with it. I just liked the idea and what it did.
Plasma's System Monitor widget and one of its sensors have similar feature but it refreshes every 10 seconds or so, and it can't be changed to smaller interval. 

The widget shows power consumption or charging rate expressed in Watts. 
Power usage is expressed as negative value. When battery is charging, a bolt symbol is displayed. When battery is fully charged, just the bolt symbol shows. 
In options, font and update interval can be set. There is also an option to trigger red font when power usage goes above set value. 

You may need to create a file with "export QML_XHR_ALLOW_FILE_READ=1" in it and place it in ~/.config/plasma-workspace/env/. Or use EV.sh file attached. 

