<script setup lang="ts">
import { ref, onMounted, reactive, computed } from "vue";
import { getCurrentLang, t } from "@/lang/i18n";
import type { LayoutCard } from "@/types/index";
import { DownloadOutlined } from "@ant-design/icons-vue";
import { quickInstallListAddr, createAsyncTask, queryAsyncTask } from "@/services/apis/instance";
import { reportErrorMsg } from "@/tools/validator";
import Loading from "@/components/Loading.vue";
import type { QuickStartTemplate } from "@/types";
import { useAppToolsStore } from "@/stores/useAppToolsStore";
import { useLayoutCardTools } from "@/hooks/useCardTools";
import { router } from "@/config/router";

const props = defineProps<{
  card: LayoutCard;
}>();

const { getMetaOrRouteValue } = useLayoutCardTools(props.card);
const { openInputDialog } = useAppToolsStore();
const daemonId = getMetaOrRouteValue("daemonId") ?? "";
const dialog = reactive({
  show: false,
  title: "Dialog"
});

const {
  state: presetList,
  execute: getQuickInstallListAddr,
  isLoading: appListLoading
} = quickInstallListAddr();

const appList = computed(() => {
  // For MCSManager v9
  const v9List: any[] = presetList.value as unknown as any[];
  if (v9List?.[0]?.info && v9List?.[0]?.mc) {
    const list = v9List.map((v) => {
      return {
        ...v,
        language: "all",
        title: v.mc,
        runtime: `Java ${v.java}+`,
        description: v.info,
        hardware: v.remark,
        size: `${v.size}MB`
      };
    });
    presetList.value = {
      languages: [
        {
          label: "ALL",
          value: "all"
        }
      ],
      packages: list
    };
    return list as unknown as QuickStartTemplate[];
  }
  // Check
  if (!presetList.value?.packages || !presetList.value?.languages) {
    return [];
  }
  let list = presetList.value?.packages;
  if (searchForm.language) list = list.filter((item) => item.language === searchForm.language);
  return list;
});
const appLangList = computed(() => presetList.value?.languages || []);

const init = async () => {
  try {
    await getQuickInstallListAddr();
    if (!appList.value || appList.value.length === 0) {
      dialog.title = t("TXT_CODE_c534ca49");
      dialog.show = true;
    }
  } catch (err: any) {
    console.error(err.message);
    return reportErrorMsg(err.message);
  }
};

const installView = ref(false);
const intervalTask = ref<NodeJS.Timer>();
const percentage = ref(0);
const isInstalled = ref(false);
const searchForm = reactive({
  language: getCurrentLang()
});

const { state: newTaskInfo, execute: executeCreateAsyncTask } = createAsyncTask();

const handleSelectTemplate = async (item: QuickStartTemplate) => {
  try {
    const instanceName = await openInputDialog(t("TXT_CODE_c237192c"));
    await executeCreateAsyncTask({
      params: {
        daemonId: daemonId,
        uuid: "-",
        task_name: "quick_install"
      },
      data: {
        time: new Date().getTime(),
        newInstanceName: instanceName as string,
        targetLink: item.targetLink
      }
    });
    installView.value = true;
    isInstalled.value = false;
    percentage.value = 0;
    await startDownloadTask();
  } catch (err: any) {
    console.error(err);
    if (err.message === "Dialog closed by user") return;
    return reportErrorMsg(err.message);
  }
};

const startDownloadTask = async () => {
  if (intervalTask.value) clearInterval(intervalTask.value);
  dialog.title = t("TXT_CODE_f878fd4c");
  dialog.show = true;
  await queryStatus();
  intervalTask.value = setInterval(async () => {
    if (percentage.value <= 95) percentage.value += Math.floor(Math.random() * 6) + 1;
    await queryStatus();
  }, 3000);
};

const { state: taskInfo, execute: queryAsyncTaskStatus } = queryAsyncTask();

const queryStatus = async () => {
  try {
    if (!newTaskInfo.value) throw new Error("newTaskInfo is null");
    await queryAsyncTaskStatus({
      params: {
        daemonId: daemonId,
        uuid: "-",
        task_name: "quick_install"
      },
      data: {
        taskId: newTaskInfo.value.taskId
      }
    });
    if (taskInfo.value?.status === -1) {
      percentage.value = 100;
      dialog.title = t("TXT_CODE_7078fd28");
      installView.value = true;
      isInstalled.value = false;
      clearInterval(intervalTask.value);
    }

    if (taskInfo.value?.status === 0) {
      percentage.value = 100;
      dialog.title = t("TXT_CODE_477ece61");
      installView.value = false;
      isInstalled.value = true;
      clearInterval(intervalTask.value);
    }
  } catch (err: any) {
    console.error(err);
    return reportErrorMsg(err.message);
  }
};

const toAppDetailPage = () => {
  const instanceId = taskInfo.value?.detail.instanceUuid;
  router.push({
    path: "/instances/terminal",
    query: {
      daemonId,
      instanceId
    }
  });
};

const toCreateInstancePage = () => {
  router.push({
    path: "/quickstart"
  });
};

onMounted(async () => {
  await init();
});
</script>

<template>
  <div style="height: 100%">
    <a-row v-if="appListLoading" :gutter="[24, 24]" style="height: 100%">
      <a-col :span="24">
        <div style="height: 50vh">
          <Loading />
        </div>
      </a-col>
    </a-row>
    <a-row v-else :gutter="[24, 24]" style="height: 100%">
      <a-col :span="24" :md="24">
        <a-form layout="horizontal" :model="searchForm">
          <a-form-item class="mb-0">
            <a-radio-group v-model:value="searchForm.language">
              <a-radio-button v-for="item in appLangList" :key="item.value" :value="item.value">
                {{ item.label }}
              </a-radio-button>
            </a-radio-group>
          </a-form-item>
        </a-form>
      </a-col>
      <fade-up-animation>
        <a-col
          v-for="item in appList"
          :key="item.targetLink + item.title"
          :span="24"
          :xl="6"
          :lg="8"
          :sm="12"
        >
          <div style="display: flex; flex-grow: 1; flex-direction: column; height: 100%">
            <CardPanel style="flex-grow: 1">
              <template #title>
                <div class="ellipsis-text" style="max-width: 280px">
                  {{ item.title }}
                </div>
              </template>
              <template #body>
                <div style="min-height: 220px; position: relative">
                  <a-typography-paragraph
                    :ellipsis="{ rows: 3, expandable: true }"
                    :content="item.description"
                  >
                  </a-typography-paragraph>
                  <a-typography-paragraph>
                    <a-typography-text class="color-info">
                      <div>{{ t("TXT_CODE_18b94497") }}: {{ item.runtime }}</div>
                      <div>{{ t("TXT_CODE_683e3033") }}: {{ item.hardware }}</div>
                      <div>{{ t("TXT_CODE_94bb113a") }}: {{ item.size }}</div>
                    </a-typography-text>
                    <br />
                    <a-typography-text class="color-info"> </a-typography-text>
                    <br />
                    <a-typography-text class="color-info"> </a-typography-text>
                  </a-typography-paragraph>
                </div>

                <div
                  style="
                    position: absolute;
                    bottom: 0;
                    left: 0;
                    right: 0;
                    display: flex;
                    justify-content: center;
                  "
                >
                  <a-button
                    block
                    type="primary"
                    ghost
                    style="max-width: 180px"
                    @click="handleSelectTemplate(item)"
                  >
                    <template #icon>
                      <DownloadOutlined />
                    </template>
                    <span>{{ t("TXT_CODE_1704ea49") }}</span>
                  </a-button>
                </div>
              </template>
            </CardPanel>
          </div>
        </a-col>
      </fade-up-animation>
    </a-row>

    <a-modal
      v-model:open="dialog.show"
      :title="dialog.title"
      :mask-closable="false"
      :closable="false"
      :footer="null"
      centered
    >
      <div v-if="!appList || appList.length === 0">
        <a-typography-paragraph>
          <a-typography-text>
            {{ t("TXT_CODE_bcfaf14d") }}
          </a-typography-text>
        </a-typography-paragraph>
        <a-button @click="toCreateInstancePage()">{{ t("TXT_CODE_bc883bbb") }}</a-button>
      </div>
      <div v-if="installView || isInstalled" style="text-align: center">
        <a-progress
          style="display: block; margin-bottom: 10px"
          type="circle"
          :percent="percentage"
          :status="taskInfo?.status === -1 ? 'exception' : 'normal'"
        />
        <div v-if="installView">
          <div v-if="taskInfo?.status !== -1">
            <a-typography-paragraph>
              <a-typography-title :level="5">{{ t("TXT_CODE_32cd41d5") }}</a-typography-title>
              <a-typography-text>
                {{ t("TXT_CODE_147a2f87") }}
              </a-typography-text>
            </a-typography-paragraph>
          </div>
          <div v-if="taskInfo?.status === -1">
            <a-typography-paragraph>
              <a-typography-title :level="5">{{ t("TXT_CODE_7078fd28") }}</a-typography-title>
              <a-typography-text>
                {{ t("TXT_CODE_57cd2d04") }}
              </a-typography-text>
            </a-typography-paragraph>
            <a-button size="large" class="mr-10" @click="toCreateInstancePage()">
              {{ t("TXT_CODE_bc883bbb") }}
            </a-button>
            <a-button type="primary" size="large" danger @click="dialog.show = false">
              {{ t("TXT_CODE_b1dedda3") }}
            </a-button>
          </div>
        </div>
        <div v-if="isInstalled">
          <a-typography-paragraph>
            <a-typography-title :level="5">{{ t("TXT_CODE_477ece61") }}</a-typography-title>
            <a-typography-text>
              {{ t("TXT_CODE_ce917b27") }}
            </a-typography-text>
          </a-typography-paragraph>
          <a-button @click="toAppDetailPage()">{{ t("TXT_CODE_36417656") }}</a-button>
        </div>
      </div>
    </a-modal>
  </div>
</template>
