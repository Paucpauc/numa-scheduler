# NUMA Scheduler

NUMA-aware CPU set scheduler hook для containerd, который позволяет настраивать CPU affinity для контейнеров на основе аннотаций подов.

## Обзор

Проект предоставляет OCI hook для containerd, который автоматически настраивает CPU affinity (cpuset) для контейнеров на основе аннотаций Kubernetes подов. Это особенно полезно для NUMA-систем, где важно привязывать контейнеры к конкретным CPU узлам для оптимизации производительности.

## Архитектура

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Kubernetes    │    │    containerd    │    │   OCI Hook      │
│     Pod         │───▶│   Runtime        │───▶│  cpuset-hook    │
│  (annotations)  │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │   cgroup fs     │
                                               │  cpuset.cpus    │
                                               └─────────────────┘
```

## Функциональность

- **Автоматическая настройка CPU affinity** на основе аннотаций подов
- **Поддержка NUMA-систем** для оптимизации производительности
- **Интеграция с containerd** через OCI hooks
- **Гибкая конфигурация** через Helm chart
- **Минимальный footprint** - бинарник compiled from scratch

## Требования

- Kubernetes 1.20+
- containerd 1.4+
- Linux с поддержкой cgroups v1/v2
- Доступ к `/sys/fs/cgroup` на узлах

## Установка

### Быстрая установка

```bash
# Клонируйте репозиторий
git clone https://github.com/andurbanovich/numa-scheduler.git
cd numa-scheduler

# Соберите и установите
make build
make generate-binary
./scripts/deploy.sh
```

### Детальная установка

#### 1. Сборка бинарного файла

```bash
# Сборка для всех платформ
make build-all

# Или только для текущей платформы
make build
```

#### 2. Генерация ConfigMap

```bash
# Генерация base64 бинарного файла для ConfigMap
make generate-binary
```

#### 3. Установка через Helm

```bash
# Установка с настройками по умолчанию
helm install numa-scheduler ./deploy/helm --namespace kube-system

# Или с использованием скрипта
./scripts/deploy.sh
```

## Использование

### Настройка подов

Добавьте аннотацию `cpu-set` к вашему поду для указания CPU affinity:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: numa-aware-pod
  annotations:
    cpu-set: "0-3"  # Привязать к CPU 0,1,2,3
spec:
  containers:
  - name: app
    image: nginx:latest
```

### Примеры использования

#### Привязка к конкретным CPU

```yaml
annotations:
  cpu-set: "0,2,4"  # CPU 0, 2, 4
```

#### Привязка к диапазону CPU

```yaml
annotations:
  cpu-set: "0-7"    # CPU с 0 по 7
```

#### Комбинированная настройка

```yaml
annotations:
  cpu-set: "0-3,8-11"  # CPU 0-3 и 8-11
```

## Конфигурация

### Helm Values

Основные параметры конфигурации:

```yaml
# Использование кастомного образа вместо ConfigMap
image:
  useCustomImage: false
  repository: numa-scheduler
  tag: "latest"

# Настройки DaemonSet
daemonSet:
  updateStrategy:
    type: RollingUpdate
  terminationGracePeriodSeconds: 1

# RBAC
rbac:
  create: true

# Конфигурация containerd
containerd:
  updateConfig: true
  configPath: /etc/containerd/config.toml
  backupConfig: true

# Hook настройки
hook:
  binaryPath: /opt/cni/bin/cpuset-hook
  hookType: "createRuntime"
```

### Полная конфигурация

Смотрите [`deploy/helm/values.yaml`](deploy/helm/values.yaml) для всех доступных опций.

## Разработка

### Структура проекта

```
.
├── cmd/                    # Основные приложения
│   └── cpuset-hook/       # OCI hook приложение
├── internal/              # Внутренние пакеты
│   └── cpuset/           # Логика работы с cpuset
├── deploy/               # Файлы развертывания
│   └── helm/            # Helm chart
├── scripts/              # Скрипты сборки и развертывания
├── idea/                 # Идеи и прототипы
├── Dockerfile           # Dockerfile для сборки образа
├── Makefile            # Makefile для удобной сборки
└── README.md           # Документация
```

### Сборка и тестирование

```bash
# Установка зависимостей
make deps

# Сборка
make build

# Тесты
make test

# Сборка Docker образа
make docker-build

# Линтинг
make lint

# Проверка безопасности
make sec
```

### Скрипты

#### Сборка

```bash
# Полная сборка
./scripts/build.sh all

# Только бинарник
./scripts/build.sh binary

# Только Docker образ
./scripts/build.sh docker
```

#### Развертывание

```bash
# Установка
./scripts/deploy.sh

# С кастомными значениями
./scripts/deploy.sh -f custom-values.yaml

# Обновление
./scripts/deploy.sh -u

# Удаление
./scripts/deploy.sh -x

# Dry run
./scripts/deploy.sh -d
```

## Архитектура OCI Hook

### Поток выполнения

1. **containerd** запускает контейнер
2. **OCI hook** вызывается на фазе `createRuntime`
3. **Hook** читает OCI спецификацию из stdin
4. **Извлекает** аннотации из спецификации
5. **Определяет** путь к cgroup контейнера
6. **Записывает** значение в `cpuset.cpus`
7. **Контейнер** запускается с настроенным CPU affinity

### Код

Основная логика находится в [`internal/cpuset/hook.go`](internal/cpuset/hook.go):

```go
type Hook struct {
    cgroupMountPrefix string
}

func (h *Hook) Process(spec *specs.Spec) error {
    // Извлечение аннотаций
    annotations := spec.Annotations
    
    // Получение cpu-set
    cpuSet := annotations["cpu-set"]
    
    // Настройка cgroup
    cgroupPath := spec.Linux.CgroupsPath
    fullPath := filepath.Join(h.cgroupMountPrefix, "cpuset", cgroupPath, "cpuset.cpus")
    
    return os.WriteFile(fullPath, []byte(cpuSet), 0644)
}
```

## Устранение проблем

### Проверка работы

```bash
# Проверка статуса DaemonSet
kubectl get daemonset numa-scheduler -n kube-system

# Проверка подов
kubectl get pods -n kube-system -l app.kubernetes.io/name=numa-scheduler

# Логи пода
kubectl logs -n kube-system -l app.kubernetes.io/name=numa-scheduler

# Проверка ConfigMap
kubectl get configmap numa-scheduler-bin -n kube-system -o yaml
```

### Частые проблемы

#### Hook не работает

1. **Проверьте права доступа** к `/sys/fs/cgroup`
2. **Убедитесь** что containerd настроен для использования hooks
3. **Проверьте** что бинарник имеет права на выполнение

#### Контейнер не запускается

1. **Проверьте** формат аннотации `cpu-set`
2. **Убедитесь** что указанные CPU существуют на узле
3. **Проверьте** логи hook для диагностики

#### Проблемы с NUMA

1. **Проверьте** топологию NUMA: `numactl --hardware`
2. **Убедитесь** что ядро поддерживает NUMA: `grep NUMA /proc/cpuinfo`
3. **Проверьте** что cgroups поддерживают cpuset: `mount | grep cpuset`

## Производительность

### Метрики

- **Размер бинарника**: ~2MB (statically linked)
- **Память**: <1MB
- **CPU**: <1ms на контейнер
- **Задержка**: минимальная, выполняется до запуска контейнера

### Оптимизация

- **Статическая компиляция** для минимизации зависимостей
- **Минимальный footprint** через scratch Docker образ
- **Быстрая обработка** без лишних аллокаций

## Безопасность

### Модель безопасности

- **Требует привилегий** для записи в cgroup fs
- **Работает** с правами root на узлах
- **Изолирован** в отдельном контейнере

### Рекомендации

- **Ограничьте** доступ к ConfigMap с бинарником
- **Используйте** RBAC для контроля доступа
- **Регулярно** обновляйте образы
- **Мониторьте** логи на предмет ошибок

## Лицензия

MIT License - см. файл [LICENSE](LICENSE) для деталей.

## Вклад

1. Fork проекта
2. Создайте feature branch (`git checkout -b feature/amazing-feature`)
3. Commit изменения (`git commit -m 'Add amazing feature'`)
4. Push в branch (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

## Поддержка

- **Issues**: [GitHub Issues](https://github.com/andurbanovich/numa-scheduler/issues)
- **Discussions**: [GitHub Discussions](https://github.com/andurbanovich/numa-scheduler/discussions)
- **Email**: andrey.urbanovich@example.com

## Дорожная карта

- [ ] Поддержка cgroups v2
- [ ] Валидация CPU affinity
- [ ] Метрики и мониторинг
- [ ] Автоматическое обнаружение NUMA топологии
- [ ] Поддержка других runtime (CRI-O, docker)
- [ ] GUI для управления