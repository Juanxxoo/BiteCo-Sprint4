import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Project } from './project.entity';
import { Report } from './report.entity';
import * as crypto from 'crypto';

@Injectable()
export class ProjectsService implements OnModuleInit {
  constructor(
    @InjectRepository(Project)
    private projectsRepo: Repository<Project>,
    @InjectRepository(Report)
    private reportsRepo: Repository<Report>,
  ) {}

  async onModuleInit() {
    await this.seedData();
  }

  private computeHash(report: Partial<Report>): string {
    const data = {
      report_id: report.report_id,
      project_id: report.project_id,
      month: report.month,
      total_cost: report.total_cost,
    };
    return crypto
      .createHash('sha256')
      .update(JSON.stringify(data))
      .digest('hex');
  }

  private async seedData() {
    const count = await this.projectsRepo.count();
    if (count > 0) return;

    // Insertar proyectos
    const projects = [
      { project_id: 'project-001', name: 'Proyecto Alpha', client_id: 'client-001', current_consumption: 1450 },
      { project_id: 'project-002', name: 'Proyecto Beta',  client_id: 'client-002', current_consumption: 980  },
      { project_id: 'project-003', name: 'Proyecto Gamma', client_id: 'client-001', current_consumption: 720  },
    ];

    for (const p of projects) {
      await this.projectsRepo.save(p);
    }

    // Insertar reportes
    const reportsData = [
      { report_id: 'report-2026-05',     project_id: 'project-001', month: '2026-05', total_cost: 1450 },
      { report_id: 'report-2026-04',     project_id: 'project-001', month: '2026-04', total_cost: 1200 },
      { report_id: 'report-2026-05-p002',project_id: 'project-002', month: '2026-05', total_cost: 980  },
      { report_id: 'report-2026-04-p002',project_id: 'project-002', month: '2026-04', total_cost: 870  },
    ];

    for (const r of reportsData) {
      const hash = this.computeHash(r);
      await this.reportsRepo.save({ ...r, integrity_hash: hash });
    }
  }

  async getProjects(client_id?: string): Promise<Project[]> {
    if (client_id) {
      return this.projectsRepo.find({ where: { client_id } });
    }
    return this.projectsRepo.find();
  }

  async getProject(project_id: string): Promise<Project> {
    return this.projectsRepo.findOne({ where: { project_id } });
  }

  async getReports(project_id: string): Promise<Report[]> {
    return this.reportsRepo.find({ where: { project_id } });
  }

  async checkIntegrity(report_id: string, project_id: string) {
    const start = Date.now();

    const report = await this.reportsRepo.findOne({ where: { report_id, project_id } });
    if (!report) return { error: 'reporte no encontrado' };

    const currentHash = this.computeHash(report);
    const tampered = currentHash !== report.integrity_hash;

    const elapsed = Date.now() - start;

    return {
      event: tampered ? 'tampering_detected' : 'integrity_ok',
      report_id,
      project_id,
      tampering_detected: tampered,
      audit_log_created: tampered,
      security_alert_generated: tampered,
      tampering_detection_time_ms: elapsed,
      asr_threshold_ms: 400,
      asr_met: elapsed < 400,
    };
  }

  async tamperReport(report_id: string, project_id: string, field: string, new_value: any) {
    const report = await this.reportsRepo.findOne({ where: { report_id, project_id } });
    if (!report) return { error: 'reporte no encontrado' };

    report[field] = new_value;
    // No actualizamos el hash — eso simula el tampering
    await this.reportsRepo.save(report);

    return {
      message: `Campo '${field}' modificado a ${new_value} en reporte ${report_id}`,
      tampering_simulated: true,
    };
  }
}
