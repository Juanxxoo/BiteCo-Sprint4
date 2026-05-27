import { Controller, Get, Post, Param, Query, Body } from '@nestjs/common';
import { ProjectsService } from './projects.service';

@Controller()
export class ProjectsController {
  constructor(private readonly projectsService: ProjectsService) {}

  @Get('health')
  health() {
    return { status: 'ok', service: 'ms-proyectos' };
  }

  @Get('projects')
  getProjects(@Query('client_id') client_id?: string) {
    return this.projectsService.getProjects(client_id);
  }

  @Get('projects/:project_id')
  getProject(@Param('project_id') project_id: string) {
    return this.projectsService.getProject(project_id);
  }

  @Get('projects/:project_id/reports')
  getReports(@Param('project_id') project_id: string) {
    return this.projectsService.getReports(project_id);
  }

  @Post('projects/reports/integrity/check')
  checkIntegrity(@Body() body: { report_id: string; project_id: string }) {
    return this.projectsService.checkIntegrity(body.report_id, body.project_id);
  }

  @Post('projects/reports/tamper')
  tamperReport(@Body() body: { report_id: string; project_id: string; field: string; new_value: any }) {
    return this.projectsService.tamperReport(body.report_id, body.project_id, body.field, body.new_value);
  }
}
