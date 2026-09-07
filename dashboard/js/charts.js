let gaugeChart = null;
let historyChart = null;

// Plugin to draw text in the center of the Doughnut chart
const centerTextPlugin = {
    id: 'centerText',
    beforeDraw: function(chart) {
        if (chart.config.type !== 'doughnut') return;
        
        const width = chart.width;
        const height = chart.height;
        const ctx = chart.ctx;
        const centerConfig = chart.config.options.plugins.centerText;
        
        if (!centerConfig) return;

        ctx.restore();
        
        // Title (Score)
        const fontSizeTitle = (height / 100).toFixed(2);
        ctx.font = `bold ${fontSizeTitle}em Inter, sans-serif`;
        ctx.textBaseline = "middle";
        ctx.fillStyle = centerConfig.color;
        
        const textTitle = centerConfig.text;
        const textX = Math.round((width - ctx.measureText(textTitle).width) / 2);
        const textY = height / 2 - 10;
        
        ctx.fillText(textTitle, textX, textY);
        
        // Subtitle (Label)
        const fontSizeSub = (height / 250).toFixed(2);
        ctx.font = `600 ${fontSizeSub}em Inter, sans-serif`;
        ctx.fillStyle = centerConfig.subColor;
        
        const textSub = centerConfig.subText;
        const textSubX = Math.round((width - ctx.measureText(textSub).width) / 2);
        const textSubY = height / 2 + 15;
        
        ctx.fillText(textSub, textSubX, textSubY);
        
        ctx.save();
    }
};

Chart.register(centerTextPlugin);

function createGaugeChart(canvasId, score, isDark) {
    const ctx = document.getElementById(canvasId).getContext('2d');
    
    if (gaugeChart) {
        gaugeChart.destroy();
    }

    const colorConfig = isDark ? getScoreColorDark(score) : getScoreColor(score);
    const emptyColor = isDark ? '#334155' : '#e2e8f0'; // slate-700 / slate-200
    const textColor = isDark ? '#f8fafc' : '#0f172a'; // slate-50 / slate-900

    gaugeChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            datasets: [{
                data: [score, 100 - score],
                backgroundColor: [colorConfig.main, emptyColor],
                borderWidth: 0,
                borderRadius: [4, 0] // slightly round the colored part
            }]
        },
        options: {
            cutout: '75%',
            responsive: true,
            maintainAspectRatio: false,
            animation: {
                animateRotate: true,
                easing: 'easeOutQuart',
                duration: 1500
            },
            plugins: {
                tooltip: { enabled: false },
                legend: { display: false },
                centerText: {
                    text: score + '%',
                    color: textColor,
                    subText: colorConfig.label,
                    subColor: colorConfig.main
                }
            }
        }
    });
}

function createHistoryChart(canvasId, historyData, isDark) {
    const ctx = document.getElementById(canvasId).getContext('2d');
    
    if (historyChart) {
        historyChart.destroy();
    }
    
    if (!historyData || historyData.length === 0) return;

    const brand500 = '#0ea5e9';
    const gridColor = isDark ? '#334155' : '#e2e8f0'; // slate-700 / slate-200
    const textColor = isDark ? '#94a3b8' : '#64748b'; // slate-400 / slate-500

    const labels = historyData.map(h => {
        const d = new Date(h.timestamp);
        return `${d.getDate().toString().padStart(2,'0')}/${(d.getMonth()+1).toString().padStart(2,'0')} ${d.getHours().toString().padStart(2,'0')}:${d.getMinutes().toString().padStart(2,'0')}`;
    });
    
    const scores = historyData.map(h => h.score);

    // Create Gradient for fill
    const gradient = ctx.createLinearGradient(0, 0, 0, 200);
    gradient.addColorStop(0, 'rgba(14, 165, 233, 0.4)'); // brand-500 with opacity
    gradient.addColorStop(1, 'rgba(14, 165, 233, 0.0)');

    historyChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Score global',
                data: scores,
                borderColor: brand500,
                backgroundColor: gradient,
                borderWidth: 2,
                pointBackgroundColor: brand500,
                pointBorderColor: isDark ? '#0f172a' : '#ffffff',
                pointBorderWidth: 2,
                pointRadius: 4,
                pointHoverRadius: 6,
                fill: true,
                tension: 0.3
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: {
                    min: 0,
                    max: 100,
                    grid: {
                        color: gridColor,
                        drawBorder: false
                    },
                    ticks: {
                        color: textColor,
                        stepSize: 20
                    }
                },
                x: {
                    grid: {
                        display: false,
                        drawBorder: false
                    },
                    ticks: {
                        color: textColor,
                        maxTicksLimit: 7
                    }
                }
            },
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    backgroundColor: isDark ? '#1e293b' : '#ffffff',
                    titleColor: isDark ? '#f8fafc' : '#0f172a',
                    bodyColor: isDark ? '#cbd5e1' : '#475569',
                    borderColor: gridColor,
                    borderWidth: 1,
                    padding: 10,
                    displayColors: false,
                    callbacks: {
                        title: (context) => {
                            const index = context[0].dataIndex;
                            const h = historyData[index];
                            return new Date(h.timestamp).toLocaleString('fr-FR');
                        },
                        label: (context) => {
                            const index = context.dataIndex;
                            const h = historyData[index];
                            return [
                                `Score : ${h.score}%`,
                                `Machine : ${h.hostname} (${h.os})`
                            ];
                        }
                    }
                },
                annotation: {
                    // Optional: If chartjs-plugin-annotation is added later, we could draw the 50/80 threshold lines
                }
            }
        },
        plugins: [{
            id: 'customThresholdLines',
            beforeDraw: (chart) => {
                const ctx = chart.canvas.getContext('2d');
                const xAxis = chart.scales.x;
                const yAxis = chart.scales.y;
                
                const drawLine = (yValue, color) => {
                    const y = yAxis.getPixelForValue(yValue);
                    ctx.save();
                    ctx.beginPath();
                    ctx.moveTo(xAxis.left, y);
                    ctx.lineTo(xAxis.right, y);
                    ctx.lineWidth = 1;
                    ctx.strokeStyle = color;
                    ctx.setLineDash([5, 5]);
                    ctx.stroke();
                    ctx.restore();
                };
                
                // Draw 80 threshold (green) and 50 threshold (amber)
                drawLine(80, isDark ? '#059669' : '#10b981'); // emerald
                drawLine(50, isDark ? '#d97706' : '#f59e0b'); // amber
            }
        }]
    });
}

function updateCharts(report, history, isDark) {
    createGaugeChart('gaugeCanvas', report.score, isDark);
    createHistoryChart('historyCanvas', history, isDark);
}

function getScoreColor(score) {
    if (score >= 80) return { main: '#10b981', bg: '#d1fae5', label: 'ÉLEVÉ' };
    if (score >= 50) return { main: '#f59e0b', bg: '#fef3c7', label: 'MOYEN' };
    return { main: '#f43f5e', bg: '#ffe4e6', label: 'CRITIQUE' };
}

function getScoreColorDark(score) {
    if (score >= 80) return { main: '#34d399', bg: '#064e3b', label: 'ÉLEVÉ' };
    if (score >= 50) return { main: '#fbbf24', bg: '#78350f', label: 'MOYEN' };
    return { main: '#fb7185', bg: '#881337', label: 'CRITIQUE' };
}
